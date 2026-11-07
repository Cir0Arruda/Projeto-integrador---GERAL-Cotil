import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:astha_app/app.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/connection_service.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/core/theme.dart';
import 'package:astha_app/features/auth/onboarding_page.dart';
import 'package:astha_app/features/personal/personal_shell.dart';
import 'package:astha_app/models/account_models.dart';
import 'package:astha_app/repositories/account_repository.dart';
import 'package:astha_app/state/session_controller.dart';

class MemoryStore extends SessionStore {
  String? token;
  int remembered = 0;
  @override
  Future<void> writeToken(String value) async {
    token = value;
  }

  @override
  Future<String?> readToken() async => token;
  @override
  Future<String> readServerUrl() async => 'https://api.example.invalid';
  @override
  Future<void> clearToken() async {
    token = null;
  }

  @override
  Future<void> rememberIdentity(
    String token,
    Map<String, dynamic> user,
    String mode,
  ) async {
    remembered++;
  }

  @override
  Future<Map<String, dynamic>?> offlineIdentity(String token) async => null;
}

class ControlledSession extends SessionController {
  ControlledSession(super.store, super.api);
  late final diagnostic = ConnectionService(
    initialUrl: api.baseUrl,
    onServerChanged: (_) {},
    startMonitoring: false,
    client: MockClient(
      (r) async =>
          http.Response('{"status":"operational","database":"connected"}', 200),
    ),
  );
  @override
  ConnectionService get connectionService => diagnostic;
}

class SignupFixture {
  bool setup = false, failComplete = false;
  String type = 'personal';
  final calls = <({String method, String path, Map<String, dynamic> body})>[];
  final profile = <String, dynamic>{
    'id': 7,
    'name': 'Ana',
    'surname': 'Teste',
    'email': 'synthetic@example.invalid',
    'role': 'superadmin',
    'org_id': 'org-pending',
  };
  final organization = <String, dynamic>{
    'id': 'org-pending',
    'name': 'Rascunho',
    'email': 'org@example.invalid',
    'phone': 'preserved-phone',
    'address': 'preserved-address',
    'city': 'preserved-city',
    'state': 'SP',
    'cnpj': 'preserved-tax',
  };
  late final store = MemoryStore();
  late final api = ApiClient(
    baseUrl: 'https://api.example.invalid',
    client: MockClient(handle),
  );
  late final session = ControlledSession(store, api);
  Future<http.Response> handle(http.Request r) async {
    final body = r.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(r.body));
    calls.add((method: r.method, path: r.url.path, body: body));
    dynamic data;
    int status = 200;
    switch (r.url.path) {
      case '/api/auth/oauth/google':
      case '/api/auth/register':
        data = {
          'token': 'synthetic-session',
          'user': {...profile, 'setup_done': setup},
        };
        break;
      case '/api/workspace/context':
        data = {'type': type, 'setupDone': setup};
        break;
      case '/api/org/me':
        if (r.method == 'PUT') {
          organization.addAll(body);
          data = {'message': 'Saved'};
        } else {
          data = organization;
        }
        break;
      case '/api/workspace/type':
        type = body['type'];
        data = {'type': type};
        break;
      case '/api/auth/profile':
        profile.addAll(body);
        data = {'message': 'Saved'};
        break;
      case '/api/org/complete-setup':
        if (failComplete) {
          status = 503;
          data = {'error': 'Synthetic completion failure'};
        } else {
          setup = true;
          data = {'message': 'Completed'};
        }
        break;
      case '/api/auth/me':
        data = {
          ...profile,
          'setup_done': setup,
          'org_name': organization['name'],
        };
        break;
      case '/api/personal/spaces':
        data = [];
        break;
      case '/api/org/join':
        profile['org_id'] = 'org-team';
        profile['role'] = 'viewer';
        organization['id'] = 'org-team';
        type = 'corporate';
        setup = true;
        data = {'token': 'synthetic-joined-session'};
        break;
      default:
        status = 503;
        data = {'error': 'Synthetic unavailable domain'};
    }
    return http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<void> google({String? preference}) => session.signInWithGoogle(
    credential: 'synthetic-google-credential',
    nonce: 'synthetic-nonce',
    targetWorkspace: preference,
  );
}

Future<void> flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> click(WidgetTester tester, String text) async {
  final button = find.widgetWithText(FilledButton, text);
  final target = button.evaluate().isNotEmpty ? button : find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await flush(tester);
}

Future<void> close(WidgetTester tester, SignupFixture f) async {
  await tester.pumpWidget(const SizedBox());
  f.session.dispose();
  await tester.pump();
}

Widget wizard(SignupFixture f) => MultiProvider(
  providers: [
    ChangeNotifierProvider<SessionController>.value(value: f.session),
    Provider<AccountRepository>(create: (_) => AccountRepository(f.api)),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: const OnboardingPage()),
);

void main() {
  testWidgets(
    'pending Google personal default opens signup, without choosing or writing a workspace',
    (tester) async {
      final f = SignupFixture();
      await f.google();
      await tester.pumpWidget(AsthaApp(api: f.api, session: f.session));
      await flush(tester);
      expect(f.session.needsSetup, true);
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(PersonalShell), findsNothing);
      expect(find.text('Pessoal'), findsOneWidget);
      expect(find.text('Corporativo'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continuar'),
            )
            .onPressed,
        isNull,
      );
      expect(
        f.calls.where(
          (c) => c.method == 'PUT' || c.path == '/api/auth/register',
        ),
        isEmpty,
      );
      expect(f.store.remembered, 0);
      await close(tester, f);
    },
  );
  testWidgets(
    'completed Google account ignores a conflicting signup preference',
    (tester) async {
      final f = SignupFixture()
        ..setup = true
        ..type = 'corporate';
      await f.google(preference: 'personal');
      expect(f.session.needsSetup, false);
      expect(f.session.workspaceType, 'corporate');
      expect(f.session.setupPreference, isNull);
      expect(f.calls.where((c) => c.method == 'PUT'), isEmpty);
      expect(f.profile['org_id'], 'org-pending');
      await close(tester, f);
    },
  );
  testWidgets(
    'narrow personal wizard saves explicitly, preserves organization fields, and exits the signup gate',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = SignupFixture();
      await f.google();
      await tester.pumpWidget(AsthaApp(api: f.api, session: f.session));
      await flush(tester);
      await click(tester, 'Pessoal');
      await click(tester, 'Continuar');
      await click(tester, 'Continuar');
      expect(find.text('CNPJ (opcional)'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Meu escritório',
      );
      await click(tester, 'Continuar');
      expect(find.text('Revise seu cadastro'), findsOneWidget);
      expect(f.calls.where((c) => c.method == 'PUT'), isEmpty);
      await click(tester, 'Concluir cadastro');
      await flush(tester);
      expect(f.session.needsSetup, false);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(PersonalShell), findsOneWidget);
      final saved = f.calls
          .firstWhere((c) => c.path == '/api/org/me' && c.method == 'PUT')
          .body;
      expect(saved['name'], 'Meu escritório');
      expect(saved['email'], 'org@example.invalid');
      expect(saved['phone'], 'preserved-phone');
      expect(saved['address'], 'preserved-address');
      expect(saved['cnpj'], 'preserved-tax');
      expect(f.calls.where((c) => c.path == '/api/auth/register'), isEmpty);
      expect(tester.takeException(), isNull);
      await close(tester, f);
    },
  );
  testWidgets(
    'failed finalization retains review and retries the same account rather than registering again',
    (tester) async {
      final f = SignupFixture()..failComplete = true;
      await f.google();
      await tester.pumpWidget(wizard(f));
      await flush(tester);
      await click(tester, 'Corporativo');
      await click(tester, 'Continuar');
      await click(tester, 'Continuar');
      expect(find.text('CNPJ (opcional)'), findsOneWidget);
      await click(tester, 'Continuar');
      await click(tester, 'Concluir cadastro');
      expect(f.session.needsSetup, true);
      expect(find.text('Synthetic completion failure'), findsOneWidget);
      expect(find.text('Revise seu cadastro'), findsOneWidget);
      f.failComplete = false;
      await click(tester, 'Concluir cadastro');
      expect(f.session.needsSetup, false);
      expect(f.calls.where((c) => c.path == '/api/auth/register'), isEmpty);
      expect(f.profile['id'], 7);
      await close(tester, f);
    },
  );
  testWidgets(
    'restore preserves the pending setup state returned by the server',
    (tester) async {
      final f = SignupFixture();
      f.store.token = 'synthetic-session';
      await f.session.restore();
      expect(f.session.status, SessionStatus.signedIn);
      expect(f.session.needsSetup, true);
      expect(f.store.remembered, 0);
      await close(tester, f);
    },
  );
  testWidgets(
    'joining a team replaces the session before reading its new organization',
    (tester) async {
      final f = SignupFixture();
      await f.google();
      await f.session.joinWorkspace('abc12345');
      expect(f.session.needsSetup, false);
      expect(f.session.user?.orgId, 'org-team');
      expect(f.session.user?.role, 'viewer');
      expect(f.store.token, 'synthetic-joined-session');
      expect(f.api.token, 'synthetic-joined-session');
      expect(
        f.calls.firstWhere((c) => c.path == '/api/org/join').body['code'],
        'ABC12345',
      );
      await close(tester, f);
    },
  );
  testWidgets(
    'a workspace completed in another session is refreshed without overwriting it',
    (tester) async {
      final f = SignupFixture();
      await f.google();
      f.setup = true;
      f.type = 'corporate';
      await f.session.completeOnboarding(
        type: 'personal',
        name: 'Wrong',
        surname: '',
        phone: '',
        country: '',
        workspaceName: 'Wrong',
        organization: Organization.fromJson(f.organization),
      );
      expect(f.session.needsSetup, false);
      expect(f.session.workspaceType, 'corporate');
      expect(f.calls.where((c) => c.method == 'PUT'), isEmpty);
      await close(tester, f);
    },
  );
}
