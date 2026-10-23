import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

typedef SecureKeyLoader = Future<String?> Function(String name);
typedef SecureKeyWriter = Future<void> Function(String name, String value);

String operationId() {
  final random = Random.secure();
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final hex = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Future<String> offlineHash(String value) async => (await Sha256().hash(
  utf8.encode(value),
)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Only ciphertext and opaque identifiers are persisted. Keys remain in secure storage.
class OfflineStore {
  OfflineStore._(this.db, this.scope, this._key);
  final Database db;
  final String scope;
  final SecretKey _key;
  final _cipher = AesGcm.with256bits();
  static Future<OfflineStore> open({
    required String origin,
    required String org,
    required int userId,
    DatabaseFactory? factory,
    String? path,
    SecureKeyLoader? readKey,
    SecureKeyWriter? writeKey,
  }) async {
    final engine = factory ?? databaseFactory;
    final db = await engine.openDatabase(
      path ?? '${await engine.getDatabasesPath()}/astha_offline.sqlite',
      options: OpenDatabaseOptions(
        // A previous session may still be disposing its connection. Sharing
        // that handle would let its close invalidate the newly signed-in user.
        singleInstance: false,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA secure_delete=ON');
        },
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE cache (scope TEXT NOT NULL, id TEXT NOT NULL, envelope TEXT NOT NULL, saved_at INTEGER NOT NULL, PRIMARY KEY(scope,id))',
          );
          await db.execute(
            'CREATE TABLE outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, scope TEXT NOT NULL, id TEXT NOT NULL, envelope TEXT NOT NULL, state TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, UNIQUE(scope,id))',
          );
          await db.execute(
            'CREATE INDEX idx_outbox_scope_state ON outbox(scope,state,seq)',
          );
        },
      ),
    );
    try {
      final scope = await offlineHash(jsonEncode([origin, org, userId]));
      const secure = FlutterSecureStorage();
      final read = readKey ?? (String key) => secure.read(key: key);
      final write =
          writeKey ??
          (String key, String value) => secure.write(key: key, value: value);
      var raw = await read('offline_key_$scope');
      if (raw == null) {
        final rows = await db.rawQuery(
          'SELECT (SELECT COUNT(*) FROM cache WHERE scope=?)+(SELECT COUNT(*) FROM outbox WHERE scope=?) AS total',
          [scope, scope],
        );
        if ((rows.first['total'] as int) > 0) {
          throw StateError(
            'Não foi possível recuperar a chave dos registros offline.',
          );
        }
        raw = base64Encode(
          await (await AesGcm.with256bits().newSecretKey()).extractBytes(),
        );
        await write('offline_key_$scope', raw);
      }
      return OfflineStore._(db, scope, SecretKey(base64Decode(raw)));
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<String> _seal(dynamic value, String id) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: _key,
      aad: utf8.encode('$scope:$id'),
    );
    return jsonEncode({
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  Future<dynamic> _open(String value, String id) async {
    final b = jsonDecode(value) as Map<String, dynamic>;
    final bytes = await _cipher.decrypt(
      SecretBox(
        base64Decode(b['c']),
        nonce: base64Decode(b['n']),
        mac: Mac(base64Decode(b['m'])),
      ),
      secretKey: _key,
      aad: utf8.encode('$scope:$id'),
    );
    return jsonDecode(utf8.decode(bytes));
  }

  Future<String> cacheId(String path, Map<String, String>? query) async {
    final sorted = Map.fromEntries(
      (query ?? {}).entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return offlineHash(jsonEncode([path, sorted]));
  }

  Future<void> cache(
    String path,
    Map<String, String>? query,
    dynamic value,
  ) async {
    final record = {'path': path, 'query': query, 'value': value};
    if (utf8.encode(jsonEncode(record)).length > 2 * 1024 * 1024) return;
    final id = await cacheId(path, query), envelope = await _seal(record, id);
    await db.transaction((txn) async {
      await txn.insert('cache', {
        'scope': scope,
        'id': id,
        'envelope': envelope,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await txn.query(
        'cache',
        columns: ['id'],
        where: 'scope=?',
        whereArgs: [scope],
        orderBy: 'saved_at DESC',
      );
      for (final row in rows.skip(30)) {
        await txn.delete(
          'cache',
          where: 'scope=? AND id=?',
          whereArgs: [scope, row['id']],
        );
      }
    });
  }

  Future<Map<String, dynamic>?> cached(
    String path,
    Map<String, String>? query,
  ) async {
    final id = await cacheId(path, query),
        rows = await db.query(
          'cache',
          where: 'scope=? AND id=?',
          whereArgs: [scope, id],
          limit: 1,
        );
    if (rows.isEmpty) return null;
    final saved = rows.first['saved_at'] as int,
        age = DateTime.now().millisecondsSinceEpoch - saved;
    if (age < 0 || age > 24 * 60 * 60 * 1000) return null;
    return {
      'value': (await _open(rows.first['envelope'] as String, id))['value'],
      'savedAt': saved,
    };
  }

  Future<String?> materialEtag(String code) async {
    final direct = await cached(
      '/api/materials/${Uri.encodeComponent(code)}',
      null,
    );
    if (direct?['value'] is Map && direct!['value']['sync_etag'] is String) {
      return direct['value']['sync_etag'];
    }
    final rows = await db.query(
      'cache',
      where: 'scope=?',
      whereArgs: [scope],
      orderBy: 'saved_at DESC',
    );
    for (final row in rows) {
      if (DateTime.now().millisecondsSinceEpoch - (row['saved_at'] as int) >
          24 * 60 * 60 * 1000) {
        continue;
      }
      final entry = await _open(row['envelope'] as String, row['id'] as String);
      if (entry['path'] == '/api/materials' && entry['value'] is List) {
        for (final item in entry['value']) {
          if (item is Map &&
              item['code'] == code &&
              item['sync_etag'] is String) {
            return item['sync_etag'];
          }
        }
      }
    }
    return null;
  }

  Future<void> enqueue(Map<String, dynamic> operation) async {
    if (utf8.encode(jsonEncode(operation)).length > 1024 * 1024) {
      throw StateError('Operação grande demais para salvar offline.');
    }
    final id = operation['id'] as String,
        envelope = await _seal({'operation': operation}, id),
        now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              "SELECT COUNT(*) FROM outbox WHERE scope=? AND state IN ('pending','conflict','rejected')",
              [scope],
            ),
          ) ??
          0;
      if (count >= 250) {
        throw StateError(
          'Revise as pendências antes de registrar novas operações.',
        );
      }
      await txn.insert('outbox', {
        'scope': scope,
        'id': id,
        'envelope': envelope,
        'state': 'pending',
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<List<Map<String, dynamic>>> jobs({bool onlyPending = false}) async {
    final rows = await db.query(
      'outbox',
      where: onlyPending
          ? "scope=? AND state='pending'"
          : "scope=? AND state<>'confirmed' AND state<>'discarded'",
      whereArgs: [scope],
      orderBy: 'seq',
      limit: 250,
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final data = await _open(row['envelope'] as String, row['id'] as String);
      result.add({
        ...data,
        'id': row['id'],
        'state': row['state'],
        'createdAt': row['created_at'],
      });
    }
    return result;
  }

  Future<void> mark(
    String id,
    String state, {
    String? error,
    dynamic result,
  }) async {
    if (![
      'pending',
      'confirmed',
      'conflict',
      'rejected',
      'discarded',
    ].contains(state)) {
      throw StateError('Estado inválido.');
    }
    final rows = await db.query(
      'outbox',
      where: 'scope=? AND id=?',
      whereArgs: [scope, id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final data = await _open(rows.first['envelope'] as String, id);
    if (state == 'confirmed' || state == 'discarded') data.remove('operation');
    if (error != null) data['error'] = error;
    if (result != null && state != 'confirmed') data['result'] = result;
    await db.update(
      'outbox',
      {
        'state': state,
        'envelope': await _seal(data, id),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'scope=? AND id=?',
      whereArgs: [scope, id],
    );
    // Preserve the last confirmed read for a later outage. Every cache read
    // carries its original timestamp and is explicitly presented as offline.
    // The next successful GET replaces it; queued writes never fabricate reads.
    await db.delete(
      'outbox',
      where: "scope=? AND state IN ('confirmed','discarded') AND updated_at<?",
      whereArgs: [
        scope,
        DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> close() => db.close();
}
