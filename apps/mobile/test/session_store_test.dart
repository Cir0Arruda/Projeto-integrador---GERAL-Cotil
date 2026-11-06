import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/core/config.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'background snapshot rejects logout, expired identity and origin mismatch without deleting auth',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final store = SessionStore();
      await store.writeServerUrl(AppConfig.productionServerUrl);
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
      final token = 'synthetic.$payload.signature';
      await store.writeToken(token);
      await store.rememberIdentity(token, {
        'id': 7,
        'org_id': 'qa-org',
      }, 'corporate');
      final snapshot = await store.readBackgroundSession();
      expect(snapshot?.userId, 7);
      expect(snapshot?.org, 'qa-org');
    await (await SharedPreferences.getInstance()).remove('server_url_api_v3');
    expect((await store.readBackgroundSession())?.userId, 7);
      await (await SharedPreferences.getInstance()).setBool(
        'session_blocked',
        true,
      );
      expect(await store.readBackgroundSession(), isNull);
      await (await SharedPreferences.getInstance()).remove('session_blocked');
      await store.writeServerUrl('https://different.example.invalid');
      expect(await store.readBackgroundSession(), isNull);
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), token);
      await store.writeServerUrl(AppConfig.productionServerUrl);
      final raw = await const FlutterSecureStorage().read(
        key: 'offline_identity',
      );
      final identity = jsonDecode(raw!) as Map<String, dynamic>;
      identity['until'] = 0;
      await const FlutterSecureStorage().write(
        key: 'offline_identity',
        value: jsonEncode(identity),
      );
      expect(await store.readBackgroundSession(), isNull);
    },
  );
  test(
    'first VPS revision replaces an old explicit-local selection without deleting unrelated saved data',
    () async {
      SharedPreferences.setMockInitialValues({
        'server_url_api_v3': 'http://127.0.0.1:3000',
        'explicit_local_recovery': true,
        'unrelated_preference': 'preserved',
      });
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'old-local-token',
        'auth_token_origin': 'http://127.0.0.1:3000',
      });
      final store = SessionStore();
      expect(await store.readServerUrl(), AppConfig.productionServerUrl);
      expect(await store.readToken(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'unrelated_preference',
        ),
        'preserved',
      );
      await store.writeServerUrl('http://127.0.0.1:3000');
      expect(await SessionStore().readServerUrl(), 'http://127.0.0.1:3000');
    },
  );
  test(
    'legacy COTIL/local defaults migrate to VPS; explicit recovery remains selectable',
    () async {
      for (final old in [
        'https://clone.cotil.unicamp.br',
        'http://143.106.241.4:3000',
        'http://10.0.2.2:3000',
      ]) {
        SharedPreferences.setMockInitialValues({'server_url_api_v3': old});
        FlutterSecureStorage.setMockInitialValues({
          'auth_token': 'old-token',
          'auth_token_origin': old,
        });
        final store = SessionStore();
        expect(await store.readServerUrl(), AppConfig.defaultServerUrl);
        expect(await store.readToken(), isNull);
      }
      SharedPreferences.setMockInitialValues({});
      final store = SessionStore();
      await store.writeServerUrl('http://127.0.0.1:3000');
      expect(await SessionStore().readServerUrl(), 'http://127.0.0.1:3000');
      expect(
        () => store.writeServerUrl('https://clone.cotil.unicamp.br'),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'tokens without origin and tokens from another server are discarded',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'legacy-secure-session',
      });
      final store = SessionStore();
      expect(await store.readToken(), isNull);
      await store.writeToken('synthetic-session');
      await store.writeServerUrl('https://other.example.invalid');
      expect(await store.readToken(), isNull);
    },
  );
  test(
    'plaintext legacy token is discarded, secure write has no plaintext duplicate and logout persists',
    () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'legacy-value'});
      FlutterSecureStorage.setMockInitialValues({});
      final store = SessionStore();
      expect(await store.readToken(), isNull);
      await store.writeToken('synthetic-session');
      expect(await store.readToken(), 'synthetic-session');
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        isNull,
      );
      await store.clearToken();
      expect(await SessionStore().readToken(), isNull);
    },
  );
}
