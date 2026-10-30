// ============================================================================
// ★ REPOSITÓRIO WMS - CONEXÃO COM AS APIS DO SISTEMA ★
// Aqui ficam todas as funções que conversam com o backend pela rede :3
// Elas chamam os endpoints HTTP da API, pegam o JSON que o servidor responde
// e transformam em objetos Dart bonitinhos pra tela poder desenhar (｡•̀ᴗ-)✧
// ============================================================================

import '../core/api_client.dart';
import '../core/config.dart';
import '../models/warehouse_models.dart';
import '../models/wms_models.dart';

class WmsRepository {
  WmsRepository(this._api);

  // Esse é o nosso cliente HTTP amigo que faz os envios pro servidor (づ｡◕‿‿◕｡)づ
  final ApiClient _api;

  // ==========================================================================
  // ★ API: GET /api/materials (REQUISITO DA TÂNIA BASSO!)
  // Busca a lista com todos os materiais do estoque no servidor :3
  // O servidor devolve um array de JSON e a gente mapeia cada um pra MaterialItem!
  // ==========================================================================
  Future<List<MaterialItem>> materials({
    int? warehouseId,
    String? search,
  }) async {
    final query = <String, String>{};
    if (warehouseId != null) query['warehouse_id'] = '$warehouseId';
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    // Bate lá na porta /api/materials da API pedindo os dados (o^▽^o)
    final data = await _api.get(
      '/api/materials',
      query: query.isEmpty ? null : query,
    );
    // Transforma cada pedacinho de JSON recebido em um objeto MaterialItem :3
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(MaterialItem.fromJson)
        .toList();
  }

  // API: GET /api/materials/:code
  // Procura um material específico pelo códigozinho dele no estoque (✿◠‿◠)
  Future<MaterialItem?> findMaterial(String code, {int? warehouseId}) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    try {
      final data = await _api.get(
        '/api/materials/${Uri.encodeComponent(normalized)}',
      );
      if (data is Map<String, dynamic>) {
        final item = MaterialItem.fromJson(data);
        if (warehouseId == null ||
            item.warehouseId == null ||
            item.warehouseId == warehouseId) {
          return item;
        }
      }
    } on ApiException catch (e) {
      if (e.status != 404) rethrow;
    } catch (_) {}
    // Se a busca direta não achar, tenta buscar com filtro pra garantir que não perde nada (TwT)
    final matches = await materials(
      warehouseId: warehouseId,
      search: normalized,
    );
    for (final item in matches) {
      if (item.code.toLowerCase() == normalized.toLowerCase()) return item;
    }
    return null;
  }

  // API: POST /api/materials
  // Cria e salva um material novinho em folha lá no banco de dados pela API :3
  Future<MaterialItem> createMaterial(Map<String, dynamic> payload) async {
    final data = await _api.post('/api/materials', payload);
    return MaterialItem.fromJson(data as Map<String, dynamic>);
  }

  // API: PUT /api/materials/:code
  // Atualiza as informações de um material que já existe (preço, quantidade, etc) (*¯︶¯*)
  Future<MaterialItem> updateMaterial(
    String code,
    Map<String, dynamic> payload,
  ) async {
    final data = await _api.put(
      '/api/materials/${Uri.encodeComponent(code)}',
      payload,
    );
    return MaterialItem.fromJson(data as Map<String, dynamic>);
  }

  // API: DELETE /api/materials/:code
  // Apaga um material do estoque quando a gente não vai mais usar ele (;-;)
  Future<void> deleteMaterial(String code) =>
      _api.delete('/api/materials/${Uri.encodeComponent(code)}');

  // API: GET /api/materials/:code/files
  // Busca anexos e manuais em PDF relacionados a um item específico (｡•̀ᴗ-)✧
  Future<List<MaterialFile>> materialFiles(String code) async {
    final data = await _api.get(
      '/api/materials/${Uri.encodeComponent(code)}/files',
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(MaterialFile.fromJson)
        .toList();
  }

  // API: GET /api/warehouse/insights
  // Busca estatísticas espertas do armazém (quantos itens tão em baixa, valor total, etc) :3
  Future<StockInsights> stockInsights(int warehouseId) async {
    final data = await _api.get(
      '/api/warehouse/insights',
      query: {'warehouse_id': '$warehouseId'},
    );
    return StockInsights.fromJson(data as Map<String, dynamic>);
  }

  // API: GET /api/movements
  // Busca o histórico de tudo que entrou e saiu do armazém ao longo do tempo (o^▽^o)
  Future<List<MovementRecord>> movements({bool? entries, int? limit}) async {
    final query = <String, String>{
      'limit': '${limit ?? AppConfig.movementHistoryLimit}',
    };
    if (entries != null) query['type'] = entries ? 'entrada' : 'saida';
    final data = await _api.get('/api/movements', query: query);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(MovementRecord.fromJson)
        .toList();
  }

  // API: POST /api/movements/entry ou /exit
  // Registra quando um item chega da fábrica (entrada) ou vai embora pro cliente (saída) (づ｡◕‿‿◕｡)づ
  Future<MovementResult> registerMovement({
    required bool entry,
    required String code,
    required double quantity,
    String? nfNumber,
    String? reason,
    String? notes,
    String? password,
    String? withdrawalId,
  }) async {
    if (!entry) {
      if (password == null || password.isEmpty || withdrawalId == null) {
        throw const ApiException('Confirme sua senha para aprovar a retirada.');
      }
      final data = await _api.remote(
        'POST',
        '/api/movements/qr-exit',
        body: {
          'code': code,
          'quantity': quantity,
          'operation_id': withdrawalId,
          'current_password': password,
          if (reason != null) 'reason': reason,
          if (notes != null) 'notes': notes,
        },
      );
      final response = data as Map<String, dynamic>;
      return MovementResult.fromJson(
        response['result'] as Map<String, dynamic>,
      );
    }
    final payload = <String, dynamic>{
      'code': code,
      'quantity': quantity,
      if (entry && nfNumber != null) 'nf_number': nfNumber,
      if (reason != null) 'reason': reason,
      if (notes != null) 'notes': notes,
    };
    final data = await _api.post(
      entry ? '/api/movements/entry' : '/api/movements/exit',
      payload,
    );
    return MovementResult.fromJson(data as Map<String, dynamic>);
  }

  // API: GET /api/components
  // Lista componentes industriais cadastrados pro catálogo :3
  Future<List<ComponentItem>> components() async {
    final data = await _api.get('/api/components');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ComponentItem.fromJson)
        .toList();
  }

  // API: GET /api/warehouse/tabs
  // Busca as abas e nomes de todos os armazéns que o usuário tem acesso (｡•̀ᴗ-)✧
  Future<List<WarehouseTab>> warehouses() async {
    final data = await _api.get('/api/warehouse/tabs');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(WarehouseTab.fromJson)
        .toList();
  }

  // API: GET /api/warehouse/layout?warehouse_id=...
  // Pega a planta 2D e 3D do armazém (paredes, prateleiras, esteiras e máquinas) (*¯︶¯*)
  Future<Blueprint> blueprint(int warehouseId) async {
    final data = await _api.get(
      '/api/warehouse/layout',
      query: {'warehouse_id': '$warehouseId'},
    );
    return Blueprint.fromJson(data as Map<String, dynamic>);
  }

  // API: GET /api/warehouse/layout?layout_id=...
  // Pega a planta do armazém pelo ID direto do layout :3
  Future<Blueprint> blueprintByLayout(int layoutId) async {
    final data = await _api.get(
      '/api/warehouse/layout',
      query: {'layout_id': '$layoutId'},
    );
    return Blueprint.fromJson(data as Map<String, dynamic>);
  }
}
