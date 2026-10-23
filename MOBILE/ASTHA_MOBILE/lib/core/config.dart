import 'dart:convert';
import 'package:flutter/foundation.dart';

class AppConfig {
  static const _configuredUrl = String.fromEnvironment('ASTHA_API_URL');
  static const productionServerUrl = 'https://136.111.89.192';
  static String get defaultServerUrl =>
      _configuredUrl.isNotEmpty ? _configuredUrl : productionServerUrl;
  static const requestTimeout = Duration(seconds: 12);
  static const pingTimeout = Duration(seconds: 5);
  static const movementHistoryLimit = 200;
  static const minPasswordLength = 15;
  static bool isRetiredServer(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.host == '143.106.241.4' ||
            uri.host == 'cotil.unicamp.br' ||
            uri.host.endsWith('.cotil.unicamp.br'));
  }

  static bool isLocalRecovery(String value) => [
    'localhost',
    '127.0.0.1',
    '::1',
    '10.0.2.2',
  ].contains(Uri.tryParse(value)?.host);
  static String normalizeServerUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    final local =
        uri != null &&
        ['localhost', '127.0.0.1', '::1', '10.0.2.2'].contains(uri.host);
    if (isRetiredServer(value.trim()) ||
        uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && local && !kReleaseMode))) {
      throw const FormatException(
        'Informe a origem HTTPS da API. HTTP local é permitido apenas no desenvolvimento.',
      );
    }
    return uri.origin;
  }

  static bool validPassword(String value) =>
      value.runes.length >= minPasswordLength &&
      utf8.encode(value).length <= 72 &&
      !RegExp(r'^(.)\1+$', unicode: true).hasMatch(value) &&
      !RegExp(
        r'^(password|senha|123456789|qwerty|administrator|administrador)[\d!@#$]*$',
        caseSensitive: false,
      ).hasMatch(value);
}
