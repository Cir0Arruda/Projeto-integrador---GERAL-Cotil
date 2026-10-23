// ============================================================================
// ★ CONTROLADOR DO GALPÃO ATIVO (WAREHOUSE_CONTROLLER.DART) ★
// Cuida de buscar a lista de armazéns/galpões da empresa na API (✿◠‿◠)
// 1) Chama GET /api/warehouses pra trazer todos os galpões :3
// 2) Guarda qual galpão tá selecionado no momento (｡•̀ᴗ-)✧
// 3) Avisa o app inteiro quando o operador escolhe outro galpão! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/warehouse_models.dart';
import '../repositories/wms_repository.dart';

// O guardião dos galpões cadastrados no backend :3
class WarehouseController extends ChangeNotifier {
  WarehouseController(this._repository);

  final WmsRepository _repository;

  List<WarehouseTab> _tabs = const [];
  WarehouseTab? _selected;
  bool _loading = false;
  String? _error;

  List<WarehouseTab> get tabs => _tabs;
  WarehouseTab? get selected => _selected;
  int? get selectedId => _selected?.id;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _tabs = await _repository.warehouses();
      final previous = _selected?.id;
      _selected = _tabs.isEmpty
          ? null
          : _tabs.firstWhere((tab) => tab.id == previous, orElse: () => _tabs.first);
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void select(WarehouseTab tab) {
    if (_selected?.id == tab.id) return;
    _selected = tab;
    notifyListeners();
  }

  void selectById(int id) {
    if (_selected?.id == id) return;
    for (final tab in _tabs) {
      if (tab.id == id) {
        _selected = tab;
        notifyListeners();
        return;
      }
    }
  }
}
