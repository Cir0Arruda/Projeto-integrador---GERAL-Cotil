import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/features/auth/recovery_page.dart';
import 'package:astha_app/repositories/account_repository.dart';

Future<void> mount(WidgetTester tester, ApiClient api) => tester.pumpWidget(
  ChangeNotifierProvider<ApiClient>.value(
    value: api,
    child: const MaterialApp(home: RecoveryPage()),
  ),
);
void main() {
  testWidgets(
    'unavailable SMTP preserves saved-code recovery at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (r) async => http.Response('{"emailRecoveryAvailable":false}', 200),
        ),
      );
      await mount(tester, api);
      await tester.pumpAndSettle();
      expect(find.text('Enviar código por e-mail'), findsNothing);
      expect(find.text('Redefinir senha'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets(
    'email request and password reset use the public API without queuing',
    (tester) async {
      final calls = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient((r) async {
          calls.add(r);
          return http.Response(
            jsonEncode(
              r.method == 'GET'
                  ? {'emailRecoveryAvailable': true}
                  : {
                      'message': r.url.path.endsWith('/email')
                          ? 'Solicitação recebida.'
                          : 'Senha redefinida.',
                    },
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await mount(tester, api);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'synthetic@example.invalid',
      );
      await tester.tap(find.text('Enviar código por e-mail'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitação recebida.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'abcdefghijklmnopqrstuv',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Synthetic new password 2026!',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Synthetic new password 2026!',
      );
      await tester.ensureVisible(find.text('Redefinir senha'));
      await tester.tap(find.text('Redefinir senha'));
      await tester.pumpAndSettle();
      expect(find.text('Voltar ao login'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      final posts = calls.where((r) => r.method == 'POST').toList();
      expect(posts.map((r) => r.url.path), [
        '/api/account/recover/email',
        '/api/account/recover',
      ]);
      expect(jsonDecode(posts[0].body), {'email': 'synthetic@example.invalid'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets(
    'leaving during reset does not access disposed password controllers',
    (tester) async {
      final reply = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (r) async => r.method == 'GET'
              ? http.Response('{"emailRecoveryAvailable":false}', 200)
              : reply.future,
        ),
      );
      await mount(tester, api);
      await tester.pumpAndSettle();
      for (final entry in [
        'synthetic@example.invalid',
        'abcdefghijklmnopqrstuv',
        'Synthetic new password 2026!',
        'Synthetic new password 2026!',
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.key),
          entry.value,
        );
      }
      await tester.ensureVisible(find.text('Redefinir senha'));
      await tester.tap(find.text('Redefinir senha'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      reply.complete(http.Response('{"message":"Senha redefinida."}', 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      api.close();
    },
  );
  testWidgets(
    'malformed successful response cannot crash or confirm recovery',
    (tester) async {
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (r) async => http.Response(
            r.method == 'GET' ? '{"emailRecoveryAvailable":true}' : 'null',
            200,
          ),
        ),
      );
      await mount(tester, api);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'synthetic@example.invalid',
      );
      await tester.tap(find.text('Enviar código por e-mail'));
      await tester.pumpAndSettle();
      expect(
        find.text('Resposta inválida da API. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  test(
    'invite email is a separate explicit authenticated HTTP action',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        token: 'synthetic-test-token',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('{"message":"Aceito pelo SMTP."}', 200);
        }),
      );
      expect(
        await AccountRepository(api).sendInviteEmail(7),
        'Aceito pelo SMTP.',
      );
      expect(requests.single.url.path, '/api/org/invites/7/email');
      expect(requests.single.method, 'POST');
      expect(
        requests.single.headers['Authorization'],
        'Bearer synthetic-test-token',
      );
      api.close();
    },
  );
}
