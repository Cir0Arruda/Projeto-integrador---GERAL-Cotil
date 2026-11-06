import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/state/session_controller.dart';
import 'package:astha_app/widgets/offline_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
    'scheduler failure stays visible in pending panel without disabling offline records',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('astha-scheduler-notice-'),
      ))!;
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(directory.path);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      );
      final api = ApiClient(
        baseUrl: 'https://qa.example.invalid',
        client: MockClient((r) async {
          if (r.url.path == '/api/auth/login') {
            return http.Response(
              jsonEncode({
                'token': 'synthetic.$payload.signature',
                'user': {
                  'id': 7,
                  'org_id': 'qa-org',
                  'name': 'QA',
                  'email': 'qa@example.invalid',
                  'role': 'admin',
                },
              }),
              200,
            );
          }
          expect(r.url.path, '/api/workspace/context');
          return http.Response('{"type":"corporate","setupDone":true}', 200);
        }),
      );
      final session = SessionController(SessionStore(), api);
      try {
        await SessionStore().writeServerUrl(api.baseUrl);
        // No Workmanager host exists in this unit-test engine. Registration must
        // fail visibly while encrypted SQLite remains available to the user.
        await tester.runAsync(
          () => session.signIn('qa@example.invalid', 'synthetic-password'),
        );
        expect(session.status, SessionStatus.signedIn);
        final offline = api.offline!;
        expect(offline.notice, contains('não pôde ser agendada'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OfflinePanel(api: api, controller: offline),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('não pôde ser agendada'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(offline.shutdown);
      } finally {
        session.dispose();
        debugDefaultTargetPlatformOverride = null;
        await tester.runAsync(() => directory.delete(recursive: true));
      }
    },
  );
}
