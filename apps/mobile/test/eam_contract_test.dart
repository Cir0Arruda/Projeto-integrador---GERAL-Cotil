import 'dart:async';
import 'dart:convert';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/offline_coordinator.dart';
import 'package:astha_app/core/session_store.dart';
import 'package:astha_app/core/theme.dart';
import 'package:astha_app/features/eam/counter_reading_dialog.dart';
import 'package:astha_app/features/eam/eam_page.dart';
import 'package:astha_app/models/account_models.dart';
import 'package:astha_app/models/eam_models.dart';
import 'package:astha_app/repositories/eam_repository.dart';
import 'package:astha_app/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class TestSession extends SessionController {
  TestSession(ApiClient api, this.role) : super(SessionStore(), api);
  final String role;
  @override
  UserProfile get user => UserProfile(
    id: 1,
    name: 'Synthetic',
    email: 'qa@example.invalid',
    role: role,
  );
}

class DeferredInvalidation implements OfflineCoordinator {
  final entered = Completer<void>(), resume = Completer<void>();
  @override
  Future<void> invalidateReads() async {
    entered.complete();
    await resume.future;
  }

  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'old EAM response is discarded when identity changes during cache invalidation',
    () async {
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        token: 'old-synthetic-session',
        client: MockClient(
          (_) async => http.Response('{"generated":[1]}', 201),
        ),
      );
      final invalidation = DeferredInvalidation();
      api.offline = invalidation;
      final result = api.remote(
        'POST',
        '/api/eam/assets/1/counters',
        body: {'operating_hours': 1},
      );
      final expectation = expectLater(
        result,
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      await invalidation.entered.future;
      api.token = 'new-synthetic-session';
      invalidation.resume.complete();
      await expectation;
      expect(api.dataRevision, 0);
      api.close();
    },
  );
  test(
    'preventive model follows API calendar, counter and inactive fields',
    () {
      final plan = PreventivePlan.fromJson({
        'id': 2,
        'asset_id': 7,
        'title': 'Lubrificação',
        'interval_days': 30,
        'interval_hours': '250.5',
        'interval_cycles': 1000,
        'next_due_hours': '1250.5',
        'next_due_cycles': 9000,
        'active': 0,
      });
      expect(plan.frequencyDays, 30);
      expect(plan.intervalHours, 250.5);
      expect(plan.intervalCycles, 1000);
      expect(plan.nextDueHours, 1250.5);
      expect(plan.nextDueCycles, 9000);
      expect(plan.status, 'inactive');
      expect(PreventivePlan.fromJson({'active': '1'}).status, 'active');
    },
  );
  test(
    'confirmed EAM writes invalidate derived views; rejection does not',
    () async {
      for (final status in [201, 403, 503]) {
        final api = ApiClient(
          baseUrl: 'https://api.example.invalid',
          client: MockClient(
            (r) async => http.Response('{"generated":[]}', status),
          ),
        );
        final op = EamRepository(api).recordCounter(assetId: 1, hours: 1500.5);
        if (status == 201) {
          await op;
          expect(api.dataRevision, 1);
        } else {
          await expectLater(op, throwsA(isA<ApiException>()));
          expect(api.dataRevision, 0);
        }
        api.close();
      }
    },
  );
  for (final input in ['1500,5', 'NaN', 'Infinity', '1499', '1000000001']) {
    testWidgets('counter input $input is validated and cannot submit twice', (
      tester,
    ) async {
      var calls = 0;
      double? saved;
      final pending = Completer<void>();
      const asset = AssetItem(
        id: 1,
        code: 'TEST',
        name: 'Synthetic',
        status: 'active',
        operatingHours: 1500,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CounterReadingDialog(
              asset: asset,
              onSave: (hours, cycles) async {
                calls++;
                saved = hours;
                await pending.future;
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, input);
      await tester.tap(find.text('Salvar leitura'));
      await tester.pump();
      if (input == '1500,5') {
        expect(calls, 1);
        expect(saved, 1500.5);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        pending.complete();
        await tester.pumpAndSettle();
      } else {
        expect(calls, 0);
        expect(
          find.textContaining('Informe ao menos uma leitura válida'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('viewer does not receive a counter write control', (
    tester,
  ) async {
    final api = ApiClient(
      baseUrl: 'https://api.example.invalid',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/assets')
                ? [
                    {
                      'id': 1,
                      'asset_code': 'TEST',
                      'name': 'Synthetic asset',
                      'status': 'active',
                    },
                  ]
                : [],
          ),
          200,
        ),
      ),
    );
    final session = TestSession(api, 'viewer');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ApiClient>.value(value: api),
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<EamRepository>.value(value: EamRepository(api)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: EamPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetic asset'));
    await tester.pumpAndSettle();
    expect(find.text('REGISTRAR HORÍMETRO / CICLOS'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
