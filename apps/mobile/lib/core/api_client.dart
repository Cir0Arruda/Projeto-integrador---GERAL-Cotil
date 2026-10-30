import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import 'offline_coordinator.dart';
export 'api_exception.dart';

/// Identity and writes are always validated by the API, without SQL fallback.
class ApiClient extends ChangeNotifier {
  int dataRevision = 0;
  bool _closed = false;
  OfflineCoordinator? offline;
  DateTime? offlineValidUntil;
  void attachOffline(OfflineCoordinator value, DateTime until) {
    detachOffline();
    offline = value;
    offlineValidUntil = until;
    notifyListeners();
  }

  void detachOffline() {
    offline?.dispose();
    offline = null;
    offlineValidUntil = null;
    notifyListeners();
  }

  ApiClient({required String baseUrl, this.token, http.Client? client})
    : _baseUrl = AppConfig.normalizeServerUrl(baseUrl),
      _http = client ?? http.Client();
  final http.Client _http;
  String _baseUrl;
  String? token;
  void Function()? onUnauthorized;
  String get baseUrl => _baseUrl;
  bool get hasToken => token != null;
  set baseUrl(String value) {
    final next = AppConfig.normalizeServerUrl(value);
    if (next != _baseUrl) {
      token = null;
      detachOffline();
    }
    _baseUrl = next;
  }

  static Future<bool> ping(String baseUrl) async {
    final client = http.Client();
    try {
      final url = AppConfig.normalizeServerUrl(baseUrl);
      final request = http.Request('GET', Uri.parse('$url/api/health'))
        ..followRedirects = false;
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(AppConfig.pingTimeout);
      final body = jsonDecode(response.body);
      return response.statusCode == 200 &&
          body is Map &&
          body['status'] == 'operational' &&
          [
            'astha-raven-web',
            'astha-raven-desktop',
          ].contains(body['application']);
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<Uint8List> download(String path) async {
    if (!path.startsWith('/api/materials/') ||
        path.contains('..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const ApiException('Caminho de arquivo inválido.');
    }
    final origin = _baseUrl, session = token;
    final request = http.Request('GET', Uri.parse('$origin$path'))
      ..followRedirects = false;
    if (session != null) request.headers['Authorization'] = 'Bearer $session';
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request),
      ).timeout(AppConfig.requestTimeout);
    } catch (_) {
      throw const ApiException(
        'Não foi possível baixar o modelo 3D. Tente novamente.',
      );
    }
    if (_baseUrl != origin || token != session) {
      throw const ApiException('A sessão mudou.', status: 401);
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Modelo indisponível ou sem permissão de acesso.',
        status: response.statusCode,
      );
    }
    if (response.bodyBytes.length > 10 * 1024 * 1024 ||
        response.bodyBytes.isEmpty) {
      throw const ApiException('Modelo vazio ou maior que 10 MB.');
    }
    return response.bodyBytes;
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);
  Future<dynamic> delete(String path, {Map<String, String>? query}) =>
      _send('DELETE', path, query: query);
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) {
    final current = offline;
    if (current != null) {
      if (offlineValidUntil == null ||
          !DateTime.now().isBefore(offlineValidUntil!)) {
        onUnauthorized?.call();
        throw const ApiException(
          'A sessão offline venceu. Reconecte e entre novamente.',
          status: 401,
        );
      }
      return current.dispatch(method, path, query: query, body: body);
    }
    return remote(method, path, query: query, body: body);
  }

  Future<dynamic> remote(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (!path.startsWith('/api/') ||
        path.contains('..') ||
        path.contains('#')) {
      throw const ApiException('Caminho de API inválido.');
    }
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    final currentToken = token;
    if (currentToken != null) {
      request.headers['Authorization'] = 'Bearer $currentToken';
    }
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await _http.send(request),
      ))().timeout(AppConfig.requestTimeout);
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar à API. Confira o registro antes de repetir uma alteração.',
      );
    }
    if (_closed || _baseUrl != uri.origin || token != currentToken) {
      throw const ApiException(
        'A sessão mudou durante a consulta.',
        status: 401,
      );
    }
    dynamic decoded;
    try {
      decoded = response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        'Resposta inválida da API.',
        status: response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final confirmedSync =
          path == '/api/sync/operations' &&
          decoded is Map &&
          body?['id'] != null &&
          decoded['id'] == body?['id'] &&
          decoded['confirmed'] == true;
      final stockWrite =
          method != 'GET' &&
          (path.startsWith('/api/materials') ||
              path.startsWith('/api/movements/'));
      if (confirmedSync || stockWrite) {
        // The server has committed. Cache failures must not turn it into a failed write.
        try {
          await offline?.invalidateReads();
        } catch (_) {}
        if (!_closed && token == currentToken && _baseUrl == uri.origin) {
          dataRevision++;
          notifyListeners();
        }
      }
      return decoded;
    }
    if (response.statusCode == 401 &&
        currentToken != null &&
        !path.startsWith('/api/auth/')) {
      onUnauthorized?.call();
    }
    if (decoded is Map &&
        decoded['result'] is Map &&
        decoded['result']['error'] is String) {
      throw ApiException(
        decoded['result']['error'] as String,
        status: response.statusCode,
      );
    }
    throw ApiException(
      decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Não foi possível concluir a operação.',
      status: response.statusCode,
    );
  }

  void close() {
    _closed = true;
    token = null;
    detachOffline();
    _http.close();
    super.dispose();
  }
}
