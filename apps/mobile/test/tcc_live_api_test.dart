// Manual contract gate against the coordinator's disposable local MySQL/API only.
import 'dart:convert';
import 'dart:io';
import 'package:astha_app/core/api_client.dart';
import 'package:astha_app/core/offline_store.dart';
import 'package:astha_app/repositories/eam_repository.dart';
import 'package:astha_app/repositories/wms_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fixturePath = String.fromEnvironment('ASTHA_TCC_FIXTURES');
  const statePath = String.fromEnvironment('ASTHA_TCC_STATE');
  const phase = String.fromEnvironment(
    'ASTHA_TCC_PHASE',
    defaultValue: 'write',
  );
  test(
    'Flutter repositories persist and read the same state as Web/Electron',
    () async {
      final fixture =
          jsonDecode(await File(fixturePath).readAsString())
              as Map<String, dynamic>;
      final base = Uri.parse(fixture['base'] as String);
      expect(['127.0.0.1', 'localhost'], contains(base.host));
      expect(base.scheme, 'http');
      expect(base.port, 3001);
      final accounts = (fixture['accounts'] as List)
          .cast<Map<String, dynamic>>();
      final owner = accounts.firstWhere(
        (a) => a['org_id'] == 'tcc-alpha' && a['role'] == 'superadmin',
      );
      final api = ApiClient(baseUrl: base.origin);
      Future<void> login(Map<String, dynamic> account) async {
        api.token = null;
        final answer =
            await api.post('/api/auth/login', {
                  'email': account['email'],
                  'password': account['password'],
                })
                as Map<String, dynamic>;
        api.token = answer['token'] as String;
      }

      try {
        await login(owner);
        final state =
            jsonDecode(await File(statePath).readAsString())
                as Map<String, dynamic>;
        final repo = WmsRepository(api);
        final current = await repo.findMaterial(state['code'] as String);
        expect(current, isNotNull);
        expect(current!.quantity, (state['expected'] as num).toDouble());
        if (phase == 'write') {
          final withdrawal = await repo.registerMovement(
            entry: false,
            code: current.code,
            quantity: .125,
            password: owner['password'] as String,
            withdrawalId: operationId(),
          );
          expect(withdrawal.newStock, closeTo(current.quantity - .125, 1e-9));
          final item = await repo.createMaterial({
            'code': 'M-${DateTime.now().millisecondsSinceEpoch}',
            'description': 'Synthetic Flutter cross-client material',
            'quantity': 3.125,
            'unit_price': 12.34,
            'warehouse_id': current.warehouseId,
          });
          expect((await repo.findMaterial(item.code))!.quantity, 3.125);
          state['expected'] = current.quantity - .125;
          state['flutterCode'] = item.code;
          state['flutterExpected'] = item.quantity;
          final eam = EamRepository(api);
          await eam.assets();
          await eam.workOrders();
          await eam.preventivePlans();
          await eam.reliabilityAssets();
          await File(statePath).writeAsString(jsonEncode(state));
          expect(api.dataRevision, greaterThanOrEqualTo(2));
        }
        final other = accounts.firstWhere(
          (a) => a['org_id'] != 'tcc-alpha' && a['role'] == 'superadmin',
        );
        await login(other);
        expect(await repo.findMaterial(current.code), isNull);
      } finally {
        api.close();
      }
    },
    skip: fixturePath.isEmpty || statePath.isEmpty,
  );
}
