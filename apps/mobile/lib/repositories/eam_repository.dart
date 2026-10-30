// ============================================================================
// ★ REPOSITÓRIO DE GESTÃO DE ATIVOS E MANUTENÇÃO (EAM_REPOSITORY.DART) ★
// Cuida de todas as máquinas pesadas, empilhadeiras, esteiras e ordens de
// serviço para manter o galpão funcionando sem nenhuma quebra inesperada! (✿◠‿◠)
// APIs utilizadas:
// 1) GET /api/eam/assets                 -> Lista todas as máquinas e equipamentos cadastrados :3
// 2) GET /api/eam/work-orders            -> Busca as ordens de serviço abertas no sistema (*¯︶¯*)
// 3) POST /api/eam/work-orders           -> Abre um novo chamado de manutenção preventiva/corretiva (｡•̀ᴗ-)✧
// 4) GET /api/eam/plans                  -> Puxa planos preventivos e rotinas periódicas :3
// 5) GET /api/eam/reliability/summary    -> Mostra indicadores de confiabilidade (MTBF / MTTR) ヽ(>∀<☆)ノ
// 6) POST /api/eam/assets/:id/counters   -> Registra horímetro e ciclos de trabalho das máquinas (o^▽^o)
// ============================================================================

import '../core/api_client.dart';
import '../models/eam_models.dart';

// O gerente digital de manutenção mecânica e elétrica do sistema :3
class EamRepository {
  EamRepository(this._api);

  // Nosso mensageiro que dispara chamadas HTTP autenticadas para o servidor :3
  final ApiClient _api;

  // Busca todas as máquinas industriais, empilhadeiras e sensores cadastrados (✿◠‿◠)
  // API chamada: GET /api/eam/assets
  Future<List<AssetItem>> assets() async {
    final data = await _api.get('/api/eam/assets');
    // Converte os dados brutos da API em objetos tipados com status e tag patrimonial! :3
    return (data as List).cast<Map<String, dynamic>>().map(AssetItem.fromJson).toList();
  }

  // Lista todas as ordens de serviço pendentes, em andamento ou concluídas (*¯︶¯*)
  // API chamada: GET /api/eam/work-orders
  Future<List<WorkOrder>> workOrders() async {
    final data = await _api.get('/api/eam/work-orders');
    return (data as List).cast<Map<String, dynamic>>().map(WorkOrder.fromJson).toList();
  }

  // Abre uma ordem de serviço novinha para a equipe de técnicos consertar algo! (｡•̀ᴗ-)✧
  // API chamada: POST /api/eam/work-orders
  Future<void> createWorkOrder({
    required int assetId,
    required String title,
    required String type,
    required String priority,
    String? description,
  }) =>
      _api.post('/api/eam/work-orders', {
        'asset_id': assetId,
        'title': title,
        'type': type,
        'priority': priority,
        if (description != null) 'description': description,
      });

  // Puxa a lista de planos de manutenção preventiva com cronogramas e checklists :3
  // API chamada: GET /api/eam/plans
  Future<List<PreventivePlan>> preventivePlans() async {
    final data = await _api.get('/api/eam/plans');
    return (data as List).cast<Map<String, dynamic>>().map(PreventivePlan.fromJson).toList();
  }

  // Retorna os cálculos de confiabilidade estatística de cada máquina (MTBF, MTTR, disponibilidade) ヽ(>∀<☆)ノ
  // API chamada: GET /api/eam/reliability/summary
  Future<List<ReliabilityAsset>> reliabilityAssets() async {
    final data = await _api.get('/api/eam/reliability/summary');
    final map = data as Map<String, dynamic>;
    final raw = map['assets'];
    // Se não tiver nenhuma máquina com dados de confiabilidade, retorna vazio numa boa :3
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>().map(ReliabilityAsset.fromJson).toList();
  }

  // Registra as leituras de horímetro (horas operadas) ou contador de ciclos do equipamento! (o^▽^o)
  // API chamada: POST /api/eam/assets/:id/counters
  Future<void> recordCounter({
    required int assetId,
    double? hours,
    double? cycles,
  }) =>
      _api.post('/api/eam/assets/$assetId/counters', {
        if (hours != null) 'operating_hours': hours,
        if (cycles != null) 'operating_cycles': cycles,
      });
}
