import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'dart:convert';
import 'offline_store.dart';

class BackgroundSession {
  const BackgroundSession(this.origin, this.token, this.org, this.userId);
  final String origin, token, org;
  final int userId;
  bool sameAs(BackgroundSession? other) =>
      other != null &&
      origin == other.origin &&
      token == other.token &&
      org == other.org &&
      userId == other.userId;
}

class SessionStore {
  static const _tokenKey = 'auth_token', _serverKey = 'server_url_api_v3';
  static const _deploymentKey = 'api_deployment_revision';
  static const _deploymentRevision = 'vps-2026-10-21';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Read-only snapshot. Reload preferences because workers use another isolate.
  /// Never migrates configuration or deletes a newer foreground session.
  Future<BackgroundSession?> readBackgroundSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (prefs.getBool('session_blocked') == true) return null;
      final saved = prefs.getString(_serverKey);
      final origin = AppConfig.normalizeServerUrl(
        saved ?? AppConfig.defaultServerUrl,
      );
      final token = await _secure.read(key: _tokenKey);
      if (token == null ||
          await _secure.read(key: 'auth_token_origin') != origin) {
        return null;
      }
      final raw = await _secure.read(key: 'offline_identity');
      if (raw == null) return null;
      final value = jsonDecode(raw);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (value is! Map ||
          value['origin'] != origin ||
          value['digest'] != await offlineHash(token) ||
          value['until'] is! int ||
          value['verifiedAt'] is! int ||
          now >= value['until'] ||
          now < value['verifiedAt']) {
        return null;
      }
      final user = value['user'];
      if (user is! Map ||
          user['id'] is! int ||
          user['id'] <= 0 ||
          user['org_id'] is! String ||
          (user['org_id'] as String).isEmpty) {
        return null;
      }
      await prefs.reload();
      if (prefs.getBool('session_blocked') == true ||
          prefs.getString(_serverKey) != saved ||
          await _secure.read(key: _tokenKey) != token) {
        return null;
      }
      return BackgroundSession(origin, token, user['org_id'], user['id']);
    } catch (_) {
      return null;
    }
  }

  Future<String> readServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var saved = prefs.getString(_serverKey);
    if (prefs.getString(_deploymentKey) != _deploymentRevision) {
      // Migrate earlier installations once, including the old explicit-local
      // setting. Later manual recovery choices remain valid. Offline queues
      // and other origin-scoped records are not deleted or reassigned.
      if (saved != null &&
          (AppConfig.isRetiredServer(saved) ||
              AppConfig.isLocalRecovery(saved))) {
        saved = AppConfig.defaultServerUrl;
        await prefs.setString(_serverKey, saved);
        await prefs.remove('explicit_local_recovery');
      }
      await prefs.setString(_deploymentKey, _deploymentRevision);
    }
    if (saved != null) {
      // Old defaults must not silently reconnect to the retired server/lab.
      // A later deliberate recovery selection is retained. Tokens remain origin-bound.
      if (AppConfig.isRetiredServer(saved) ||
          (AppConfig.isLocalRecovery(saved) &&
              prefs.getBool('explicit_local_recovery') != true)) {
        await prefs.setString(_serverKey, AppConfig.defaultServerUrl);
        return AppConfig.defaultServerUrl;
      }
      try {
        return AppConfig.normalizeServerUrl(saved);
      } catch (_) {
        await prefs.setString(_serverKey, AppConfig.defaultServerUrl);
        await prefs.remove('explicit_local_recovery');
      }
    }
    return AppConfig.defaultServerUrl;
  }

  Future<void> writeServerUrl(String url) async {
    final normalized = AppConfig.normalizeServerUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, normalized);
    await prefs.setString(_deploymentKey, _deploymentRevision);
    await prefs.setBool(
      'explicit_local_recovery',
      AppConfig.isLocalRecovery(normalized),
    );
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    if (prefs.getBool('session_blocked') == true) return null;
    try {
      final origin = await _secure.read(key: 'auth_token_origin');
      if (origin != AppConfig.normalizeServerUrl(await readServerUrl())) {
        await clearToken();
        return null;
      }
      return await _secure.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_blocked', true);
    await prefs.remove(_tokenKey);
    final origin = AppConfig.normalizeServerUrl(await readServerUrl());
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: 'auth_token_origin', value: origin);
    await prefs.remove('session_blocked');
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_blocked', true);
    await prefs.remove(_tokenKey);
    try {
      await _secure.delete(key: _tokenKey);
      await _secure.delete(key: 'auth_token_origin');
      await _secure.delete(key: 'offline_identity');
    } catch (_) {
      // The persisted block prevents restoring a session after a storage failure.
    }
  }

  Future<void> rememberIdentity(
    String token,
    Map<String, dynamic> user,
    String mode,
  ) async {
    final parts = token.split('.');
    if (parts.length != 3) return;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final until = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
      );
      final now = DateTime.now(), cap = now.add(const Duration(hours: 24));
      final value = {
        'origin': await readServerUrl(),
        'digest': await offlineHash(token),
        'user': user,
        'mode': mode,
        'verifiedAt': now.millisecondsSinceEpoch,
        'until': (until.isBefore(cap) ? until : cap).millisecondsSinceEpoch,
      };
      await _secure.write(key: 'offline_identity', value: jsonEncode(value));
    } catch (_) {
      await _secure.delete(key: 'offline_identity');
    }
  }

  Future<Map<String, dynamic>?> offlineIdentity(String token) async {
    try {
      final raw = await _secure.read(key: 'offline_identity');
      if (raw == null) return null;
      final value = jsonDecode(raw) as Map<String, dynamic>,
          now = DateTime.now().millisecondsSinceEpoch;
      if (value['origin'] != await readServerUrl() ||
          value['digest'] != await offlineHash(token) ||
          value['until'] is! int ||
          value['verifiedAt'] is! int ||
          now >= value['until'] ||
          now < value['verifiedAt']) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }
}
