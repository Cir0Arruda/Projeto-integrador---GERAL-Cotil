import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/config.dart';

void main() {
  test(
    'rejects SQL schemes, remote plaintext and credential-bearing origins',
    () {
      for (final url in [
        'mysql://db.invalid/test',
        'http://remote.invalid',
        'https://user:pass@api.invalid',
        'https://api.invalid/api',
        'https://api.invalid?token=x',
      ]) {
        expect(() => ApiClient(baseUrl: url), throwsFormatException);
      }
    },
  );
  test(
    '401, 503 and transport failures never become authentication or write success',
    () async {
      for (final status in [401, 503]) {
        final api = ApiClient(
          baseUrl: 'https://api.example.invalid',
          client: MockClient(
            (_) async =>
                http.Response(jsonEncode({'error': 'Recusado'}), status),
          ),
        );
        await expectLater(
          api.post('/api/auth/login', {
            'email': 'test@example.invalid',
            'password': 'wrong',
          }),
          throwsA(
            isA<ApiException>().having((e) => e.status, 'status', status),
          ),
        );
        expect(api.baseUrl, 'https://api.example.invalid');
        api.close();
      }
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (_) async => throw http.ClientException('Disconnected'),
        ),
      );
      await expectLater(
        api.post('/api/movements/entry', {'quantity': 1}),
        throwsA(isA<ApiException>()),
      );
      expect(api.baseUrl, 'https://api.example.invalid');
      api.close();
    },
  );
  test(
    'requests carry the session only to the selected origin and reject redirects',
    () async {
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        token: 'test-token',
        client: MockClient((request) async {
          expect(request.url.origin, 'https://api.example.invalid');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.followRedirects, isFalse);
          return http.Response('{"id":7}', 200);
        }),
      );
      expect(await api.get('/api/auth/me'), {'id': 7});
      api.baseUrl = 'https://other.example.invalid';
      expect(api.token, isNull);
      api.close();
    },
  );
  test(
    'password policy matches server length, UTF-8 limit and repeated/common values',
    () {
      for (final value in ['short', 'a' * 15, 'é' * 40, 'password123456789']) {
        expect(AppConfig.validPassword(value), isFalse);
      }
      expect(AppConfig.validPassword('Uma frase privada 2026!'), isTrue);
    },
  );
  test(
    'defaults to https://136.111.89.192, posts login JSON and sends Bearer token on authenticated calls',
    () async {
      expect(AppConfig.productionServerUrl, 'https://136.111.89.192');
      expect(AppConfig.defaultServerUrl, 'https://136.111.89.192');

      final api = ApiClient(
        baseUrl: AppConfig.defaultServerUrl,
        client: MockClient((request) async {
          expect(request.url.origin, 'https://136.111.89.192');
          if (request.method == 'POST' &&
              request.url.path == '/api/auth/login') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body, {
              'email': 'user@astha.example',
              'password': 'Uma frase privada 2026!',
            });
            return http.Response(
              jsonEncode({
                'token': 'jwt-token-123',
                'user': {
                  'id': 1,
                  'name': 'User',
                  'email': 'user@astha.example',
                  'role': 'admin',
                  'org_id': 'org-1',
                },
              }),
              200,
            );
          }
          if (request.method == 'GET' && request.url.path == '/api/auth/me') {
            expect(request.headers['Authorization'], 'Bearer jwt-token-123');
            return http.Response(
              jsonEncode({'id': 1, 'email': 'user@astha.example'}),
              200,
            );
          }
          return http.Response('{"error":"Not found"}', 404);
        }),
      );

      final loginResp =
          await api.post('/api/auth/login', {
                'email': 'user@astha.example',
                'password': 'Uma frase privada 2026!',
              })
              as Map<String, dynamic>;
      api.token = loginResp['token'] as String;
      final meResp = await api.get('/api/auth/me') as Map<String, dynamic>;
      expect(meResp['email'], 'user@astha.example');
      api.close();
    },
  );
}
