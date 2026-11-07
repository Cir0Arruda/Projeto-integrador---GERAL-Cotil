import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/background_sync.dart';
import 'package:astha_app/core/config.dart';
import 'package:astha_app/core/offline_store.dart';
import 'package:astha_app/core/session_store.dart';

/// Only a disposable emulator and a separately-owned loopback MySQL/API fixture.
/// Never distribute this entrypoint or a build containing its fixture token.
Future<void> main() async {
  const token = String.fromEnvironment('ASTHA_NATIVE_QA_TOKEN');
  const operation = String.fromEnvironment('ASTHA_NATIVE_QA_OPERATION');
  if (kReleaseMode ||
      !const bool.fromEnvironment('ASTHA_ISOLATED_NATIVE_QA') ||
      AppConfig.defaultServerUrl != 'http://127.0.0.1:3001' ||
      token.isEmpty ||
      !RegExp(r'^[a-f0-9-]{36}$').hasMatch(operation)) {
    throw StateError(
      'Requires the explicitly isolated loopback native fixture.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: AppConfig.defaultServerUrl, token: token);
  try {
    final me = await api.remote('GET', '/api/auth/me');
    if (me is! Map || me['org_id'] != 'audit-native' || me['id'] is! int) {
      throw StateError('Unexpected authenticated fixture identity.');
    }
    final user = Map<String, dynamic>.from(me);
    final session = SessionStore();
    final initialized = prefs.getBool('qa_authenticated_initialized') == true;
    if (!initialized) {
      await session.clearToken();
      await session.writeServerUrl(api.baseUrl);
      await session.writeToken(token);
      await session.rememberIdentity(token, user, 'corporate');
      if (await session.readBackgroundSession() == null) {
        throw StateError('Native secure identity was not persisted.');
      }
    }
    final store = await OfflineStore.open(
      origin: api.baseUrl,
      org: 'audit-native',
      userId: user['id'],
      requireExistingKey: initialized,
    );
    try {
      if (initialized) {
        // Relaunch only verifies the native queue; it never creates another write.
        await prefs.setInt(
          'qa_authenticated_remaining',
          (await store.jobs()).length,
        );
        await prefs.setBool('qa_authenticated_verified', true);
      } else {
        await store.enqueue({
          'id': operation,
          'method': 'POST',
          'path': '/api/movements/entry',
          'body': {'code': 'NATIVE-BG-QA', 'quantity': 1.125},
        });
        await prefs.remove('qa_background_completed_at');
        await prefs.remove('qa_background_success');
        await prefs.setBool('qa_authenticated_initialized', true);
      }
    } finally {
      await store.close();
    }
    if (!initialized) {
      await BackgroundSync.initialize();
      await Workmanager().registerOneOffTask(
        '$backgroundSyncTask.authenticatedProbe',
        backgroundSyncTask,
        initialDelay: const Duration(seconds: 45),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await prefs.setBool('qa_authenticated_scheduled', true);
    }
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('ASTHA · validação nativa isolada')),
        ),
      ),
    );
  } finally {
    api.close();
  }
}
