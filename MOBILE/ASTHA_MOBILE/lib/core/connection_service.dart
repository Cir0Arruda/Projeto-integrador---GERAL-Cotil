import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

enum ConnectionStateStatus { checking, online, offline }

class EndpointProbeResult {
  const EndpointProbeResult({
    required this.url,
    required this.label,
    required this.reachable,
    this.latencyMs,
    this.error,
  });
  final String url, label;
  final bool reachable;
  final int? latencyMs;
  final String? error;
}

class ConnectionService with ChangeNotifier {
  ConnectionService({
    required String initialUrl,
    required this.onServerChanged,
    http.Client? client,
    bool startMonitoring = true,
  }) : _activeUrl = AppConfig.normalizeServerUrl(initialUrl),
       _client = client ?? http.Client() {
    if (startMonitoring) {
      unawaited(checkCurrent());
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => checkCurrent(),
      );
    }
  }
  final ValueChanged<String> onServerChanged;
  final http.Client _client;
  String _activeUrl;
  ConnectionStateStatus _status = ConnectionStateStatus.checking;
  int? _latencyMs;
  DateTime? _lastChecked;
  Timer? _timer;
  bool _disposed = false, _isScanning = false;
  int _revision = 0;
  List<EndpointProbeResult> _lastScan = [];
  static const _customUrlsKey = 'astha_custom_servers';
  String get activeUrl => _activeUrl;
  ConnectionStateStatus get status => _status;
  int? get latencyMs => _latencyMs;
  DateTime? get lastChecked => _lastChecked;
  List<EndpointProbeResult> get lastScan => List.unmodifiable(_lastScan);
  bool get isScanning => _isScanning;
  bool get isOnline => _status == ConnectionStateStatus.online;
  static List<({String url, String label})> defaultEndpoints() => [
    (url: AppConfig.defaultServerUrl, label: 'ASTHA principal · VPS'),
    if (!kReleaseMode && !kIsWeb)
      (
        url: 'http://127.0.0.1:3000',
        label: 'Recuperação local · seleção manual',
      ),
  ];
  Future<EndpointProbeResult> probe(
    String rawUrl, {
    String? label,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final watch = Stopwatch()..start();
    try {
      final url = AppConfig.normalizeServerUrl(rawUrl);
      final request = http.Request('GET', Uri.parse('$url/api/health'))
        ..followRedirects = false;
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      final body = jsonDecode(response.body);
      final ok =
          response.statusCode == 200 &&
          body is Map &&
          body['status'] == 'operational' &&
          [
            'astha-raven-web',
            'astha-raven-desktop',
          ].contains(body['application']);
      return EndpointProbeResult(
        url: url,
        label: label ?? url,
        reachable: ok,
        latencyMs: ok ? watch.elapsedMilliseconds : null,
        error: ok ? null : 'API indisponível',
      );
    } catch (_) {
      return EndpointProbeResult(
        url: rawUrl,
        label: label ?? rawUrl,
        reachable: false,
        error: 'Não foi possível validar a API.',
      );
    }
  }

  Future<bool> checkCurrent() async {
    final revision = ++_revision;
    final result = await probe(_activeUrl);
    if (_disposed || revision != _revision) return false;
    _lastChecked = DateTime.now();
    _status = result.reachable
        ? ConnectionStateStatus.online
        : ConnectionStateStatus.offline;
    _latencyMs = result.latencyMs;
    notifyListeners();
    return result.reachable;
  }

  Future<List<String>> loadCustomUrls() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_customUrlsKey) ?? []).where((url) {
      try {
        AppConfig.normalizeServerUrl(url);
        return true;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Future<void> addCustomUrl(String rawUrl) async {
    final url = AppConfig.normalizeServerUrl(rawUrl);
    final prefs = await SharedPreferences.getInstance();
    final urls = (await loadCustomUrls()).toSet()..add(url);
    await prefs.setStringList(_customUrlsKey, urls.toList());
  }

  Future<void> removeCustomUrl(String rawUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final urls = await loadCustomUrls();
    urls.remove(rawUrl);
    await prefs.setStringList(_customUrlsKey, urls);
  }

  /// Recheck selected origin; never transfer a session to a discovered server.
  Future<String?> autoScanAndConnect({bool forceScan = false}) async {
    if (_isScanning) return null;
    _isScanning = true;
    if (!_disposed) notifyListeners();
    try {
      final ok = await checkCurrent();
      if (!_disposed) {
        _lastScan = [
          EndpointProbeResult(
            url: _activeUrl,
            label: 'API selecionada',
            reachable: ok,
            latencyMs: _latencyMs,
          ),
        ];
      }
      return ok ? _activeUrl : null;
    } finally {
      _isScanning = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> setServerManually(String newUrl) async {
    _activeUrl = AppConfig.normalizeServerUrl(newUrl);
    _status = ConnectionStateStatus.checking;
    onServerChanged(_activeUrl);
    return checkCurrent();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
