import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/background_sync.dart';
import 'package:astha_app/core/offline_store.dart';
import 'package:astha_app/core/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const identity = BackgroundSession(
    'https://qa.example.invalid',
    'synthetic-token',
    'qa-org',
    7,
  );
  late Directory directory;
  late Map<String, String> keys;
  late BackgroundSession? current;
  late List<Map<String, dynamic>> sent;
  late int status;
  late Map<String, dynamic> me;
  late void Function()? afterMe;
  late bool loseReply;
  Future<OfflineStore> open(BackgroundSession s) => OfflineStore.open(
    origin: s.origin,
    org: s.org,
    userId: s.userId,
    factory: databaseFactoryFfi,
    path: '${directory.path}/offline.sqlite',
    readKey: (key) async => keys[key],
    writeKey: (key, value) async {
      keys[key] = value;
    },
  );
  BackgroundSyncRunner runner({Duration? budget}) => BackgroundSyncRunner(
    readSession: () async => current,
    openStore: open,
    budget: budget ?? const Duration(seconds: 20),
    createClient: (s) => ApiClient(
      baseUrl: s.origin,
      token: s.token,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        expect(request.url.origin, identity.origin);
        expect(request.followRedirects, isFalse);
        if (request.url.path == '/api/auth/me') {
          afterMe?.call();
          return http.Response(jsonEncode(me), 200);
        }
        expect(request.url.path, '/api/sync/operations');
        final operation = jsonDecode(request.body) as Map<String, dynamic>;
        sent.add(operation);
        if (loseReply) throw const SocketException('synthetic lost reply');
        return http.Response(
          jsonEncode(
            status == 200
                ? {
                    'id': operation['id'],
                    'confirmed': true,
                    'result': {'ok': true},
                  }
                : {'error': 'synthetic conflict'},
          ),
          status,
        );
      }),
    ),
  );
  Future<List<String>> enqueue(int count) async {
    final store = await open(identity);
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      final id = operationId();
      ids.add(id);
      await store.enqueue({
        'id': id,
        'method': 'POST',
        'path': '/api/movements/entry',
        'body': {'code': 'QA', 'quantity': 1.125},
      });
    }
    await store.close();
    return ids;
  }

  Future<List<Map<String, dynamic>>> remaining() async {
    final store = await open(identity);
    try {
      return await store.jobs();
    } finally {
      await store.close();
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('astha-background-');
    keys = {};
    current = identity;
    sent = [];
    status = 200;
    me = {'id': 7, 'org_id': 'qa-org'};
    afterMe = null;
    loseReply = false;
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'reopens encrypted SQLite and confirms only durable operation IDs',
    () async {
      final ids = await enqueue(2);
      final cached = await open(identity);
      await cached.cache('/api/materials', null, [
        {'code': 'QA', 'quantity': 0},
      ]);
      await cached.close();
      expect(await runner().run(), isTrue);
      expect(sent.map((x) => x['id']), ids);
      expect(sent.first['body']['quantity'], 1.125);
      expect(await remaining(), isEmpty);
      final reopened = await open(identity);
      expect(await reopened.cached('/api/materials', null), isNull);
      await reopened.close();
    },
  );
  test(
    'logout and origin changes stop replay without losing queued writes',
    () async {
      await enqueue(1);
      current = null;
      expect(await runner().run(), isTrue);
      expect(sent, isEmpty);
      expect(await remaining(), hasLength(1));
      current = identity;
      afterMe = () {
        current = const BackgroundSession(
          'https://different.example.invalid',
          'other',
          'other-org',
          8,
        );
      };
      await runner().run();
      expect(sent, isEmpty);
      expect(await remaining(), hasLength(1));
    },
  );
  test(
    'server identity cannot select a different tenant or user outbox',
    () async {
      await enqueue(1);
      for (final wrong in [
        {'id': 8, 'org_id': 'qa-org'},
        {'id': 7, 'org_id': 'other'},
      ]) {
        me = wrong;
        expect(await runner().run(), isTrue);
      }
      expect(sent, isEmpty);
      expect(await remaining(), hasLength(1));
    },
  );
  test(
    'lost response retries the exact same ID after process recreation',
    () async {
      final ids = await enqueue(1);
      loseReply = true;
      expect(await runner().run(), isFalse);
      expect((await remaining()).single['id'], ids.single);
      loseReply = false;
      expect(await runner().run(), isTrue);
      expect(sent.map((x) => x['id']), [ids.single, ids.single]);
      expect(await remaining(), isEmpty);
    },
  );
  test(
    'conflict blocks later writes and avoids a background retry loop',
    () async {
      await enqueue(2);
      status = 409;
      expect(await runner().run(), isTrue);
      expect(sent, hasLength(1));
      expect((await remaining()).map((x) => x['state']), [
        'conflict',
        'pending',
      ]);
    },
  );
  test(
    'worker respects operation budget and keeps the remaining queue',
    () async {
      await enqueue(21);
      expect(await runner().run(), isFalse);
      expect(sent, hasLength(20));
      expect(await remaining(), hasLength(1));
    },
  );
  test(
    'expired runtime and cancelled worker do not send queued writes',
    () async {
      await enqueue(1);
      expect(await runner(budget: Duration.zero).run(), isTrue);
      final stopped = runner();
      stopped.stop();
      expect(await stopped.run(), isTrue);
      expect(sent, isEmpty);
      expect(await remaining(), hasLength(1));
    },
  );
}
