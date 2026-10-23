import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:astha_app/core/offline_store.dart';
import 'package:astha_app/core/offline_coordinator.dart';
import 'package:astha_app/core/api_exception.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Map<String, String> keys;
  Future<OfflineStore> open({int user = 7}) => OfflineStore.open(
    origin: 'https://api.example.invalid',
    org: 'org-a',
    userId: user,
    factory: databaseFactoryFfi,
    path: '${directory.path}/offline.sqlite',
    readKey: (key) async => keys[key],
    writeKey: (key, value) async {
      keys[key] = value;
    },
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('astha-offline-');
    keys = {};
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'SQLite survives close/reopen, encrypts payloads and isolates identities',
    () async {
      var store = await open();
      await store.cache('/api/materials', null, [
        {'code': 'PRIVATE-SENTINEL', 'quantity': 4, 'sync_etag': 'v1'},
      ]);
      final op = {
        'id': operationId(),
        'method': 'POST',
        'path': '/api/movements/entry',
        'body': {'code': 'PRIVATE-SENTINEL', 'quantity': 1},
      };
      await store.enqueue(op);
      await store.close();
      final raw = await File('${directory.path}/offline.sqlite').readAsBytes();
      expect(
        utf8.decode(raw, allowMalformed: true).contains('PRIVATE-SENTINEL'),
        isFalse,
      );
      store = await open();
      expect((await store.jobs()).single['id'], op['id']);
      expect(
        (await store.cached('/api/materials', null))!['value'][0]['quantity'],
        4,
      );
      await store.close();
      final other = await open(user: 8);
      expect(await other.jobs(), isEmpty);
      expect(await other.cached('/api/materials', null), isNull);
      await other.close();
    },
  );
  test(
    'lost response retries the same durable id and clears it only after confirmation',
    () async {
      final store = await open();
      var online = false, loseResponse = true, writes = 0;
      final ledger = <String, Map<String, dynamic>>{};
      final coordinator = OfflineCoordinator(store, (
        method,
        path, {
        query,
        body,
      }) async {
        if (!online) throw const ApiException('Offline');
        final id = body!['id'] as String;
        final result = ledger.putIfAbsent(id, () {
          writes++;
          return {
            'id': id,
            'confirmed': true,
            'result': {'new_stock': 5, 'quantity': 1},
          };
        });
        if (loseResponse) {
          loseResponse = false;
          throw const ApiException('Resposta perdida');
        }
        return result;
      }, startTimer: false);
      await expectLater(
        coordinator.dispatch(
          'POST',
          '/api/movements/entry',
          body: {'code': 'TEST', 'quantity': 1},
        ),
        throwsA(isA<QueuedOperationException>()),
      );
      final id = (await store.jobs()).single['id'];
      online = true;
      await coordinator.synchronize();
      expect(writes, 1);
      expect((await store.jobs()).single['id'], id);
      await coordinator.synchronize();
      expect(writes, 1);
      expect(await store.jobs(), isEmpty);
      coordinator.dispose();
      await store.close();
    },
  );
  test(
    'cache is explicit and conflicts block later operations until reviewed',
    () async {
      final store = await open();
      await store.cache('/api/materials', null, [
        {'code': 'TEST'},
      ]);
      final coordinator = OfflineCoordinator(store, (
        method,
        path, {
        query,
        body,
      }) async {
        if (method == 'GET') throw const ApiException('Offline');
        throw const ApiException('Saldo mudou', status: 409);
      }, startTimer: false);
      expect(await coordinator.dispatch('GET', '/api/materials'), [
        {'code': 'TEST'},
      ]);
      expect(coordinator.usingCache, isTrue);
      await expectLater(
        coordinator.dispatch(
          'POST',
          '/api/movements/exit',
          body: {'code': 'TEST', 'quantity': 2},
        ),
        throwsA(isA<ApiException>()),
      );
      expect((await store.jobs()).single['state'], 'conflict');
      await expectLater(
        coordinator.dispatch(
          'POST',
          '/api/movements/entry',
          body: {'code': 'TEST', 'quantity': 1},
        ),
        throwsA(isA<QueuedOperationException>()),
      );
      final pending = await store.jobs();
      expect(pending.length, 2);
      expect(pending[1]['state'], 'pending');
      await expectLater(
        coordinator.discard(pending[1]['id']),
        throwsA(isA<ApiException>()),
      );
      await coordinator.discard(pending[0]['id']);
      expect((await store.jobs()).length, 1);
      coordinator.dispose();
      await store.close();
    },
  );
  test(
    'closing an old session cannot close the new handle or erase confirmed reads',
    () async {
      final previous = await open(), current = await open();
      await previous.close();
      await current.cache('/api/materials', null, [
        {'code': 'TEST', 'quantity': 3},
      ]);
      final id = operationId();
      await current.enqueue({
        'id': id,
        'method': 'POST',
        'path': '/api/movements/entry',
        'body': {'code': 'TEST', 'quantity': 1},
      });
      await current.mark(id, 'confirmed');
      expect(await current.jobs(), isEmpty);
      expect(
        (await current.cached('/api/materials', null))!['value'][0]['quantity'],
        3,
      );
      await current.close();
    },
  );
  test(
    'one successful endpoint cannot hide a different stale cached read',
    () async {
      final store = await open();
      await store.cache('/api/materials', null, [
        {'code': 'TEST'},
      ]);
      var materialOnline = false;
      final coordinator = OfflineCoordinator(store, (
        method,
        path, {
        query,
        body,
      }) async {
        if (path == '/api/materials' && !materialOnline) {
          throw const ApiException('Offline');
        }
        return [];
      }, startTimer: false);
      await coordinator.dispatch('GET', '/api/materials');
      await coordinator.dispatch('GET', '/api/warehouse');
      expect(coordinator.usingCache, isTrue);
      materialOnline = true;
      await coordinator.dispatch('GET', '/api/materials');
      expect(coordinator.usingCache, isFalse);
      coordinator.dispose();
      await store.close();
    },
  );
}
