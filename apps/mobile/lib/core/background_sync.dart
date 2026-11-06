import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'offline_coordinator.dart';
import 'offline_store.dart';
import 'session_store.dart';

const backgroundSyncTask = 'com.astharaven.asthaApp.outbox';

bool get _supported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// No token, user, server or payload is persisted in the OS job's input data.
class BackgroundSync {
  static Future<void> initialize() async {
    if (_supported) await Workmanager().initialize(backgroundSyncDispatcher);
  }

  static Future<void> schedule() async {
    if (!_supported) return;
    await Workmanager().registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }

  static Future<void> cancel() async {
    if (_supported) await Workmanager().cancelByUniqueName(backgroundSyncTask);
  }
}

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  BackgroundSyncRunner? active;
  Workmanager().executeTask(
    (task, input) async {
      DartPluginRegistrant.ensureInitialized();
      if (task != backgroundSyncTask) return true;
      final runner = BackgroundSyncRunner();
      active = runner;
      try {
        final success = await runner.run();
        // Isolated CI probe only: no user, payload, token or origin is recorded.
        if (const bool.fromEnvironment('ASTHA_ISOLATED_NATIVE_QA')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            'qa_background_completed_at',
            DateTime.now().millisecondsSinceEpoch,
          );
          await prefs.setBool('qa_background_success', success);
        }
        return success;
      } finally {
        active = null;
      }
    },
    onTaskStopped: (task, reason) async {
      active?.stop();
    },
  );
}

typedef BackgroundSessionReader = Future<BackgroundSession?> Function();
typedef BackgroundStoreOpener =
    Future<OfflineStore> Function(BackgroundSession session);

/// Bounded replay of the existing encrypted outbox, with server authorization
/// and the same idempotency IDs used in the foreground. Never creates writes.
class BackgroundSyncRunner {
  BackgroundSyncRunner({
    BackgroundSessionReader? readSession,
    BackgroundStoreOpener? openStore,
    ApiClient Function(BackgroundSession session)? createClient,
    this.budget = const Duration(seconds: 20),
  }) : readSession = readSession ?? SessionStore().readBackgroundSession,
       openStore =
           openStore ??
           ((s) => OfflineStore.open(
             origin: s.origin,
             org: s.org,
             userId: s.userId,
             requireExistingKey: true,
           )),
       createClient =
           createClient ??
           ((s) => ApiClient(baseUrl: s.origin, token: s.token));

  final BackgroundSessionReader readSession;
  final BackgroundStoreOpener openStore;
  final ApiClient Function(BackgroundSession session) createClient;
  final Duration budget;
  bool _stopped = false;
  ApiClient? _client;

  void stop() {
    _stopped = true;
    _client?.close();
    _client = null;
  }

  Future<bool> run() async {
    final clock = Stopwatch()..start();
    OfflineCoordinator? coordinator;
    try {
      final session = await readSession();
      // Logged out, expired, locked keychain or changed origin: preserve queue.
      if (session == null || _stopped) return true;
      final api = createClient(session);
      _client = api;
      Future<dynamic> guarded(
        String method,
        String path, {
        Map<String, String>? query,
        Map<String, dynamic>? body,
      }) async {
        final current = await readSession();
        final left = budget - clock.elapsed;
        if (_stopped || left <= Duration.zero || !session.sameAs(current)) {
          throw const ApiException('Sincronização interrompida.', status: 401);
        }
        return api.remote(method, path, query: query, body: body).timeout(left);
      }

      // An unverified local JWT/identity never authorizes another tenant's queue.
      final me = await guarded('GET', '/api/auth/me');
      if (me is! Map ||
          me['id'].toString() != session.userId.toString() ||
          me['org_id'].toString() != session.org) {
        return true;
      }
      if (_stopped || clock.elapsed >= budget) return false;
      final store = await openStore(session);
      coordinator = OfflineCoordinator(store, guarded, startTimer: false);
      await coordinator.synchronize(maxOperations: 20);
      // This client is intentionally not attached to the foreground controller.
      // Remove persisted snapshots after confirmed background writes as well.
      if (api.dataRevision > 0) await coordinator.invalidateReads();
      final pending = await store.jobs();
      // Conflicts/rejections require user review; don't spin an OS retry loop.
      return pending.isEmpty || pending.first['state'] != 'pending';
    } on ApiException catch (error) {
      return error.status == 401 || error.status == 403;
    } catch (_) {
      // Never log credentials, item payloads or raw plugin/network exceptions.
      return false;
    } finally {
      try {
        if (coordinator != null) {
          await coordinator.shutdown();
          coordinator.dispose();
        }
      } finally {
        stop();
        clock.stop();
      }
    }
  }
}
