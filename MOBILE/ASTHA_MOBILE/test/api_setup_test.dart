import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:astha_app/app.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/config.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/state/session_controller.dart';
import 'package:astha_app/widgets/api_setup.dart';

void main() {
  testWidgets(
    'AsthaApp mounts ChangeNotifierProvider for ApiClient without Provider assertion errors',
    (tester) async {
      final api = ApiClient(
        baseUrl: AppConfig.defaultServerUrl,
        client: MockClient((_) async => http.Response('{"status":"operational","application":"astha-raven-web"}', 200)),
      );
      final session = SessionController(SessionStore(), api);
      await tester.pumpWidget(AsthaApp(api: api, session: session));
      expect(tester.takeException(), isNull);
      session.dispose();
    },
  );
  testWidgets(
    'unconfigured app can select HTTPS and refuses direct database addresses',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        ApiSetup(
          onConfigured: (url) async {
            selected = url;
          },
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'mysql://database.invalid/test',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.textContaining('Informe a origem HTTPS'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://api.example.invalid/',
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(selected, 'https://api.example.invalid');
    },
  );
}
