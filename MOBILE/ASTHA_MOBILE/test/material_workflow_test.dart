import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:astha_app/features/stock/material_detail_sheet.dart';
import 'package:astha_app/models/wms_models.dart';
import 'package:astha_app/models/account_models.dart';
import 'package:astha_app/repositories/wms_repository.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/state/session_controller.dart';
import 'package:astha_app/repositories/account_repository.dart';
import 'package:astha_app/features/movements/material_qr.dart';
import 'package:astha_app/features/movements/withdrawal_approval.dart';
import 'package:astha_app/features/stock/material_model_page.dart';
import 'package:astha_app/features/settings/corporate_settings_page.dart';
import 'package:astha_app/features/home/more_page.dart';

class TestSession extends SessionController {
  TestSession(super.store, super.api);
  @override
  UserProfile get user => const UserProfile(
    id: 1,
    name: 'Synthetic',
    email: 'synthetic@example.invalid',
    role: 'admin',
    orgId: 'org-a',
  );
}

void main() {
  testWidgets(
    'material shows a real scoped QR and opens 3D attachment instead of photo',
    (tester) async {
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (request) async => request.url.path.endsWith('/files')
              ? http.Response(
                  '[{"id":1,"filename":"test.stl","category":"product_3d"}]',
                  200,
                )
              : http.Response('{}', 404),
        ),
      );
      final session = TestSession(SessionStore(), api);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider.value(value: api),
            Provider(create: (_) => WmsRepository(api)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MaterialDetailSheet(
                item: MaterialItem.fromJson({
                  'code': 'ABC-1',
                  'description': 'Synthetic',
                  'quantity': 1,
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('QR Code para retirada'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modelo 3D'));
      await tester.pumpAndSettle();
      expect(find.text('Modelo 3D · ABC-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'cancelling approval never confirms withdrawal or leaves a broken dialog',
    (tester) async {
      String? answer = 'pending';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  answer = await requestWithdrawalApproval(context, 'A-1', 1);
                },
                child: const Text('Retirar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'synthetic-password');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(answer, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'QR identifies material and organization without including credentials',
    () {
      final data = materialQrPayload('ABC-1', 'org-a');
      expect(materialCodeFromQr(data, 'org-a'), 'ABC-1');
      expect(() => materialCodeFromQr(data, 'org-b'), throwsFormatException);
      for (final invalid in [
        'https://evil.invalid',
        '{}',
        'x' * 2049,
        materialQrPayload('\u0000', 'org-a'),
      ]) {
        expect(
          () => materialCodeFromQr(invalid, 'org-a'),
          throwsFormatException,
        );
      }
      expect(jsonDecode(data).keys.toSet(), {'kind', 'v', 'code', 'org'});
    },
  );
  test(
    'binary model download is authenticated, origin bound and refuses redirects',
    () async {
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        token: 'synthetic-token',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(request.followRedirects, false);
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      expect(await api.download('/api/materials/A/files/1/data'), [1, 2, 3]);
      await expectLater(
        api.download('https://evil.invalid/api/materials/A'),
        throwsA(isA<ApiException>()),
      );
      api.close();
      final redirect = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://evil.invalid'},
          ),
        ),
      );
      await expectLater(
        redirect.download('/api/materials/A/files/1/data'),
        throwsA(isA<ApiException>()),
      );
      redirect.close();
    },
  );
  test(
    'model HTML embeds bytes as data, limits resources and never interpolates filename',
    () {
      final html = materialModelHtml(
        'https://api.example.invalid',
        '</script>.stl',
        Uint8List.fromList([60, 47, 115, 99, 114, 105, 112, 116, 62]),
      );
      expect(html, contains('Content-Security-Policy'));
      expect(html, contains('ASTHAViewer3D'));
      expect(html, contains('crossorigin="anonymous"'));
      expect(html, isNot(contains('</script>.stl')));
      expect(html, isNot(contains('Bearer')));
      expect(
        () => materialModelHtml(
          'https://api.example.invalid',
          'model.html',
          Uint8List(1),
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'corporate units failure stays visible inside scrolling page without viewport crash',
    (tester) async {
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (r) async => r.url.path == '/api/org/me'
              ? http.Response('{"id":"a","name":"Synthetic"}', 200)
              : http.Response('{"error":"Falha temporária"}', 503),
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider(create: (_) => AccountRepository(api))],
          child: const MaterialApp(home: CorporateSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Tentar novamente'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets(
    'personal account option does not attempt forbidden workspace conversion',
    (tester) async {
      var requests = 0;
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient((r) async {
          requests++;
          return http.Response('{}', 403);
        }),
      );
      final session = SessionController(SessionStore(), api);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: Scaffold(body: MorePage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Conta pessoal'), 250);
      await tester.tap(find.text('Conta pessoal'));
      await tester.pumpAndSettle();
      expect(find.text('Usar uma conta pessoal'), findsOneWidget);
      await tester.tap(find.text('Continuar nesta conta'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
