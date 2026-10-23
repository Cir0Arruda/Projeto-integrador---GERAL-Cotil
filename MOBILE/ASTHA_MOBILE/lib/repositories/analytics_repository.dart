// ============================================================================
// ★ REPOSITÓRIO DE ANÁLISES E INTELIGÊNCIA (ANALYTICS_REPOSITORY.DART) ★
// Esse cara aqui é o cérebro que conversa com o servidor pra buscar gráficos,
// estudos estatísticos e relatórios analíticos do armazém! (✿◠‿◠)
// APIs utilizadas:
// 1) GET /api/analytics/studies  -> Lista todos os estudos analíticos :3
// 2) POST /api/analytics/studies -> Cria uma nova pesquisa com perguntas de negócio (*¯︶¯*)
// 3) GET /api/analytics/catalog  -> Traz o catálogo com fórmulas e métodos disponíveis (｡•̀ᴗ-)✧
// ============================================================================

import '../core/api_client.dart';
import '../models/analytics_models.dart';

// Classe responsável por fazer o meio de campo entre o app e os endpoints de analytics :3
class AnalyticsRepository {
  AnalyticsRepository(this._api);

  // Nosso carteiro virtual que sabe fazer requisições HTTP seguras :3
  final ApiClient _api;

  // Busca no backend a lista completa de estudos que foram salvos :3
  // API chamada: GET /api/analytics/studies
  Future<List<AnalyticsStudy>> studies() async {
    final data = await _api.get('/api/analytics/studies');
    // Transforma a lista de JSON que veio da internet em objetos tipados e bonitinhos! (✿◠‿◠)
    return (data as List).cast<Map<String, dynamic>>().map(AnalyticsStudy.fromJson).toList();
  }

  // Cria um estudo analítico novinho em folha no banco de dados! (｡•̀ᴗ-)✧
  // API chamada: POST /api/analytics/studies
  Future<AnalyticsStudy> createStudy(String name, String question) async {
    final data = await _api.post('/api/analytics/studies', {
      'name': name,
      'question': question,
    });
    // Retorna o estudo recém-criado com seu ID oficial gerado pelo servidor :3
    return AnalyticsStudy.fromJson(data as Map<String, dynamic>);
  }

  // Puxa o catálogo de fórmulas matemáticas e métodos analíticos suportados pelo WMS! ヽ(>∀<☆)ノ
  // API chamada: GET /api/analytics/catalog
  Future<List<AnalyticsMethod>> catalog() async {
    final data = await _api.get('/api/analytics/catalog');
    final map = data as Map<String, dynamic>;
    final methods = map['methods'];
    // Se não veio nenhum método cadastrado, retorna uma lista vazia pra não dar pau ;-;
    if (methods is! List) return const [];
    return methods.cast<Map<String, dynamic>>().map(AnalyticsMethod.fromJson).toList();
  }
}
