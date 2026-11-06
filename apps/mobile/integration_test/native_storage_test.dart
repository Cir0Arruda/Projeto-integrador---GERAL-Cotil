import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:astha_app/core/offline_store.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native secure storage, encrypted SQLite and real login screen', (
    tester,
  ) async {
    // This test touches the test installation's auth keys. Never run it on a
    // user's existing profile; CI creates a new emulator/simulator installation.
    expect(
      const bool.fromEnvironment('ASTHA_ISOLATED_NATIVE_QA'),
      isTrue,
      reason: 'Requires an explicitly disposable emulator or simulator.',
    );
    final session = SessionStore();
    final org = 'native-qa-${DateTime.now().microsecondsSinceEpoch}';
    final id = operationId();
    const token = 'synthetic-native-storage-test-token';
    const sentinel = 'PRIVATE_NATIVE_SQLITE_SENTINEL';
    OfflineStore? store;
    String? scope;
    try {
      await session.writeToken(token);
      expect(await session.readToken(), token);
      await session.clearToken();
      expect(await session.readToken(), isNull);
      store = await OfflineStore.open(
        origin: 'https://136.111.89.192',
        org: org,
        userId: 900001,
      );
      scope = store.scope;
      final secureDelete = await store.db.rawQuery('PRAGMA secure_delete');
      expect(secureDelete.single.values.single, 1);
      await store.enqueue({
        'id': id,
        'method': 'POST',
        'path': '/api/materials',
        'body': {'description': sentinel, 'quantity': 1.125},
      });
      final raw = await store.db.query(
        'outbox',
        columns: ['envelope'],
        where: 'scope=?',
        whereArgs: [scope],
      );
      expect(raw.single['envelope'].toString(), isNot(contains(sentinel)));
      await store.close();
      store = null;
      store = await OfflineStore.open(
        origin: 'https://136.111.89.192',
        org: org,
        userId: 900001,
      );
      final rows = await store.jobs(onlyPending: true);
      expect(rows.single['id'], id);
      expect(rows.single['operation']['body']['description'], sentinel);
      expect(rows.single['operation']['body']['quantity'], 1.125);
    } finally {
      if (store != null) {
        await store.db.delete('outbox', where: 'scope=?', whereArgs: [scope]);
        await store.db.delete('cache', where: 'scope=?', whereArgs: [scope]);
        await store.close();
      }
      if (scope != null) {
        await const FlutterSecureStorage().delete(key: 'offline_key_$scope');
      }
      await session.clearToken();
    }
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
