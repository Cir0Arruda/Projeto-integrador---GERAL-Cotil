import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/offline_store.dart';
import 'package:astha_app/core/offline_coordinator.dart';
import 'package:astha_app/core/theme.dart';
import 'package:astha_app/core/format.dart';
import 'package:astha_app/repositories/wms_repository.dart';
import 'package:astha_app/state/warehouse_controller.dart';
import 'package:astha_app/features/stock/material_form_dialog.dart';
import 'package:astha_app/features/stock/stock_page.dart';

class SelectedWarehouse extends WarehouseController {
  SelectedWarehouse(super.repo);
  @override
  int get selectedId => 7;
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Widget host(ApiClient api, Widget home) {
  final repo = WmsRepository(api);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ApiClient>.value(value: api),
      Provider<WmsRepository>.value(value: repo),
      ChangeNotifierProvider<WarehouseController>(
        create: (_) => SelectedWarehouse(repo),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: home),
  );
}

void main() {
  test(
    'decimal parser rejects NaN and infinity rather than accepting a false stock',
    () {
      expect(parseDecimal('1,25'), 1.25);
      expect(parseDecimal('NaN'), isNull);
      expect(parseDecimal('Infinity'), isNull);
    },
  );
  for (final invalid in [false, true]) {
    testWidgets(
      invalid
          ? 'invalid material quantity never reaches the API'
          : 'Portuguese material numbers reach the API with the selected warehouse',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? sent;
        bool? saved;
        final api = ApiClient(
          baseUrl: 'https://api.example.invalid',
          client: MockClient((r) async {
            expect(r.method, 'POST');
            expect(r.url.path, '/api/materials');
            sent = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({...sent!, 'id': 1, 'code': 'TEST'}),
              201,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        await tester.pumpWidget(
          host(
            api,
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await MaterialFormDialog.show(context);
                  },
                  child: const Text('Novo'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Novo'));
        await tester.pumpAndSettle();
        await tester.enterText(
          field('Descrição do Material *'),
          'Material sintético',
        );
        await tester.ensureVisible(field('Quantidade'));
        await tester.enterText(field('Quantidade'), invalid ? 'NaN' : '1,25');
        await tester.enterText(field('Preço (R\$)'), '12,34');
        await tester.tap(find.text('Cadastrar'));
        await tester.pumpAndSettle();
        if (invalid) {
          expect(sent, isNull);
          expect(saved, isNull);
          expect(find.textContaining('Quantidade: informe'), findsOneWidget);
        } else {
          expect(sent!['quantity'], 1.25);
          expect(sent!['unit_price'], 12.34);
          expect(sent!['warehouse_id'], 7);
          expect(
            saved,
            true,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((t) => t.data)
                .join(' | '),
          );
          expect(api.dataRevision, 1);
        }
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
  testWidgets('confirmed withdrawal refreshes an already open stock page', (
    tester,
  ) async {
    var quantity = 2.0, reads = 0;
    final api = ApiClient(
      baseUrl: 'https://api.example.invalid',
      client: MockClient((r) async {
        if (r.method == 'GET') {
          reads++;
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'code': 'STOCK-1',
                'description': 'Synthetic',
                'unit': 'UN',
                'quantity': quantity,
                'warehouse_id': 7,
              },
            ]),
            200,
          );
        }
        expect(r.url.path, '/api/movements/qr-exit');
        quantity -= .25;
        return http.Response(
          jsonEncode({
            'confirmed': true,
            'result': {'new_stock': quantity, 'quantity': .25},
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(host(api, const StockPage()));
    await tester.pumpAndSettle();
    expect(reads, 1);
    await tester.runAsync(
      () => WmsRepository(api).registerMovement(
        entry: false,
        code: 'STOCK-1',
        quantity: .25,
        password: 'synthetic-password',
        withdrawalId: operationId(),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.textContaining('1,75'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  test(
    'only confirmed writes publish refresh revisions, never rejected or queued answers',
    () async {
      for (final status in [403, 503]) {
        final api = ApiClient(
          baseUrl: 'https://api.example.invalid',
          client: MockClient(
            (_) async => http.Response('{"error":"rejected"}', status),
          ),
        );
        await expectLater(
          api.post('/api/materials', {'description': 'Test'}),
          throwsA(isA<ApiException>()),
        );
        expect(api.dataRevision, 0);
        api.close();
      }
      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (_) async => http.Response('{"confirmed":false}', 200),
        ),
      );
      await api.remote('POST', '/api/sync/operations', body: {});
      expect(api.dataRevision, 0);
      api.close();
      final mismatched = ApiClient(
        baseUrl: 'https://api.example.invalid',
        client: MockClient(
          (_) async =>
              http.Response('{"id":"another-operation","confirmed":true}', 200),
        ),
      );
      await mismatched.remote(
        'POST',
        '/api/sync/operations',
        body: {'id': 'ours'},
      );
      expect(mismatched.dataRevision, 0);
      mismatched.close();
    },
  );
  test(
    'offline confirmation invalidates stale caches and a late read cannot restore them',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('astha-stock-refresh-');
      final keys = <String, String>{};
      final store = await OfflineStore.open(
        origin: 'https://api.example.invalid',
        org: 'synthetic',
        userId: 1,
        factory: databaseFactoryFfi,
        path: '${dir.path}/offline.sqlite',
        readKey: (k) async => keys[k],
        writeKey: (k, v) async {
          keys[k] = v;
        },
      );
      final read = Completer<dynamic>();
      RemoteRequest transport = (method, path, {query, body}) async =>
          read.future;
      final coordinator = OfflineCoordinator(
        store,
        (method, path, {query, body}) =>
            transport(method, path, query: query, body: body),
        startTimer: false,
      );
      final running = coordinator.dispatch('GET', '/api/materials');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await coordinator.invalidateReads();
      read.complete([
        {'code': 'OLD', 'quantity': 2},
      ]);
      await running;
      expect(await store.cached('/api/materials', null), isNull);
      await store.cache('/api/materials', null, [
        {'code': 'STALE'},
      ], isCurrent: () => false);
      expect(await store.cached('/api/materials', null), isNull);

      final api = ApiClient(
        baseUrl: 'https://api.example.invalid',
        token: 'synthetic-token',
        client: MockClient((request) async {
          final operation = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/api/sync/operations');
          return http.Response(
            jsonEncode({
              'id': operation['id'],
              'confirmed': true,
              'result': {'code': 'NEW', 'quantity': 1.25},
            }),
            200,
          );
        }),
      );
      transport = api.remote;
      api.offline = coordinator;
      api.offlineValidUntil = DateTime.now().add(const Duration(hours: 1));
      await store.cache('/api/materials', null, [
        {'code': 'OLD'},
      ]);
      expect(await api.post('/api/materials', {'description': 'Synthetic'}), {
        'code': 'NEW',
        'quantity': 1.25,
      });
      expect(api.dataRevision, 1);
      expect(await store.cached('/api/materials', null), isNull);
      expect(await store.jobs(), isEmpty);
      api.close();
      await store.close();
      await dir.delete(recursive: true);
    },
  );
}
