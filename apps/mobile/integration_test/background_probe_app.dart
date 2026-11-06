import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:astha_app/core/background_sync.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/main.dart' as app;

/// Dedicated disposable-CI entrypoint. Never package this as a user release.
Future<void> main() async {
  if (!const bool.fromEnvironment('ASTHA_ISOLATED_NATIVE_QA')) {
    throw StateError('Requires an explicitly disposable installation.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('qa_background_completed_at');
  await prefs.remove('qa_background_success');
  await SessionStore().clearToken();
  await app.main();
  await BackgroundSync.schedule();
  // Exercise the same dispatcher after a cold process start without forcing
  // a periodic job before WorkManager's own next-run eligibility time.
  await Workmanager().registerOneOffTask(
    '$backgroundSyncTask.nativeProbe',
    backgroundSyncTask,
    initialDelay: const Duration(seconds: 45),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
  await prefs.setBool('qa_background_scheduled', true);
}
