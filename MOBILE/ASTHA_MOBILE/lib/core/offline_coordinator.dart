import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import 'offline_store.dart';

typedef RemoteRequest =
    Future<dynamic> Function(
      String method,
      String path, {
      Map<String, String>? query,
      Map<String, dynamic>? body,
    });

class OfflineCoordinator extends ChangeNotifier {
  OfflineCoordinator(this.store, this.remote, {bool startTimer = true}) {
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!paused) unawaited(synchronize());
      });
    }
    unawaited(refresh().catchError((Object _) {}));
  }
  final OfflineStore store;
  final RemoteRequest remote;
  Timer? _timer;
  bool closed = false, paused = false, busy = false, usingCache = false;
  DateTime? cacheTime;
  final Map<String, DateTime> _cachedReads = {};
  String? notice;
  List<Map<String, dynamic>> pending = [];
  bool supports(String method, String path) =>
      (method == 'POST' &&
          RegExp(r'^/api/movements/(entry|exit)$').hasMatch(path)) ||
      (method == 'POST' && path == '/api/materials') ||
      (['PUT', 'DELETE'].contains(method) &&
          RegExp(r'^/api/materials/[^/]+$').hasMatch(path)) ||
      (method == 'POST' && path == '/api/personal/spaces') ||
      (method == 'PUT' &&
          RegExp(r'^/api/personal/spaces/[1-9]\d*$').hasMatch(path)) ||
      (method == 'POST' &&
          RegExp(
            r'^/api/personal/spaces/[1-9]\d*/(archive|restore)$',
          ).hasMatch(path)) ||
      (method == 'POST' &&
          RegExp(
            r'^/api/personal/spaces/[1-9]\d*/belongings/[a-zA-Z0-9_-]+/move$',
          ).hasMatch(path));
  bool cacheable(String path) =>
      RegExp(
        r'^/api/(materials|warehouse|movements|components|eam|analytics|personal/spaces)(/|$)',
      ).hasMatch(path) &&
      !path.contains('/files') &&
      !path.endsWith('/photo');
  Future<void> refresh() async {
    if (closed) return;
    pending = await store.jobs();
    if (!closed) notifyListeners();
  }

  Future<dynamic> dispatch(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (closed) {
      throw const ApiException('Entre novamente para continuar.', status: 401);
    }
    if (method == 'GET') {
      final readId = await store.cacheId(path, query);
      try {
        final data = await remote(method, path, query: query);
        _cachedReads.remove(readId);
        usingCache = _cachedReads.isNotEmpty;
        if (cacheable(path)) {
          try {
            await store.cache(path, query, data);
          } catch (_) {
            notice = 'Não foi possível atualizar a cópia offline.';
          }
        }
        if (!closed) notifyListeners();
        return data;
      } on ApiException catch (e) {
        if ((e.status == 0 || e.status >= 500) && cacheable(path)) {
          final cached = await store.cached(path, query);
          if (cached != null) {
            usingCache = true;
            _cachedReads[readId] = DateTime.fromMillisecondsSinceEpoch(
              cached['savedAt'],
            );
            cacheTime = _cachedReads.values.reduce(
              (a, b) => a.isBefore(b) ? a : b,
            );
            if (!closed) notifyListeners();
            return cached['value'];
          }
        }
        rethrow;
      }
    }
    if (!supports(method, path)) {
      return remote(method, path, query: query, body: body);
    }
    final op = <String, dynamic>{
      'id': operationId(),
      'method': method,
      'path': path,
      'body': body ?? {},
    };
    if (['PUT', 'DELETE'].contains(method) &&
        path.startsWith('/api/materials/')) {
      final code = Uri.decodeComponent(
        path.substring('/api/materials/'.length),
      );
      var tag = await store.materialEtag(code);
      if (tag == null) {
        final current = await remote('GET', path);
        tag = current['sync_etag'] as String?;
      }
      if (tag == null) {
        throw const ApiException(
          'Atualize o material antes de editar ou excluir.',
        );
      }
      op['expected_etag'] = tag;
    }
    await store.enqueue(op);
    await refresh();
    // Preserve order: later writes must not bypass an unresolved earlier operation.
    final jobs = await store.jobs();
    if (jobs.first['id'] != op['id'] || busy) {
      throw QueuedOperationException(op['id']);
    }
    busy = true;
    try {
      return await _send(op);
    } finally {
      busy = false;
      await refresh();
    }
  }

  Future<dynamic> _send(Map<String, dynamic> op) async {
    try {
      final answer = await remote('POST', '/api/sync/operations', body: op);
      if (answer is! Map ||
          answer['id'] != op['id'] ||
          answer['confirmed'] != true) {
        throw const ApiException(
          'Confirmação de sincronização inválida.',
          status: 503,
        );
      }
      await store.mark(op['id'], 'confirmed');
      notice =
          'Alteração confirmada. Atualize a consulta para ver os dados atuais.';
      return answer['result'];
    } on ApiException catch (e) {
      if (e.status == 0 ||
          e.status >= 500 ||
          e.status == 401 ||
          e.status == 429) {
        throw QueuedOperationException(op['id']);
      }
      final state = e.status == 409 ? 'conflict' : 'rejected';
      await store.mark(op['id'], state, error: e.message);
      rethrow;
    }
  }

  Future<void> synchronize() async {
    if (closed || paused || busy) return;
    busy = true;
    if (!closed) notifyListeners();
    try {
      final jobs = await store.jobs();
      for (final job in jobs) {
        if (closed || paused) break;
        if (job['state'] != 'pending') break;
        try {
          await _send(Map<String, dynamic>.from(job['operation']));
        } on QueuedOperationException {
          break;
        } on ApiException {
          break;
        }
      }
    } catch (_) {
      notice =
          'Não foi possível sincronizar agora. As pendências continuam neste dispositivo.';
    } finally {
      busy = false;
      if (!closed) await refresh();
    }
  }

  Future<void> discard(String id) async {
    final job = pending.where((j) => j['id'] == id).first;
    if (job['state'] == 'pending') {
      throw const ApiException(
        'Uma operação sem confirmação pode já ter sido recebida. Reconecte para conferir antes de descartar.',
      );
    }
    await store.mark(id, 'discarded');
    await refresh();
  }

  @override
  void dispose() {
    closed = true;
    _timer?.cancel();
    unawaited(store.close().catchError((Object _) {}));
    super.dispose();
  }
}
