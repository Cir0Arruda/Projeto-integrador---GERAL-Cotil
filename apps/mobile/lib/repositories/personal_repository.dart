// ============================================================================
// ★ REPOSITÓRIO DE ESPAÇOS E OBJETOS PESSOAIS (PERSONAL_REPOSITORY.DART) ★
// Cuida de toda a organização da sua vida pessoal: cômodos, armários, caixas,
// gavetas e até fotos dos seus pertences guardados! (✿◠‿◠)
// APIs utilizadas:
// 1) GET /api/personal/spaces                     -> Lista todos os seus espaços pessoais :3
// 2) GET /api/personal/spaces/:id                 -> Pega um espaço detalhado com seus móveis (｡•̀ᴗ-)✧
// 3) POST /api/personal/spaces                    -> Cria um espaço novo (quarto, oficina, sala) (*¯︶¯*)
// 4) PUT /api/personal/spaces/:id                 -> Atualiza dimensões e móveis do espaço :3
// 5) POST /api/personal/spaces/:id/archive        -> Arquiva um espaço guardado (TwT)
// 6) POST /api/personal/spaces/:id/restore        -> Reativa um espaço que estava arquivado ヽ(>∀<☆)ノ
// 7) POST /api/personal/find                      -> Busca por IA pra achar onde você guardou tal coisa! (o^▽^o)
// 8) GET /api/personal/spaces/:s/objects/:o/photo -> Puxa a foto do móvel/objeto :3
// 9) GET /api/personal/spaces/:s/belongings/:b/photo -> Puxa a foto do pertence :3
// 10) POST /api/personal/spaces/:s/belongings/:b/move -> Move o pertence pra outra gaveta/nicho :3
// ============================================================================

import '../core/api_client.dart';
import '../models/personal_models.dart';

// Classe que faz todas as conversas com os endpoints do módulo pessoal :3
class PersonalRepository {
  PersonalRepository(this._api);

  // Cliente HTTP que cuida dos cabeçalhos, tokens JWT e segurança :3
  final ApiClient _api;

  // Busca todos os espaços e cômodos pessoais que o usuário cadastrou (✿◠‿◠)
  // API chamada: GET /api/personal/spaces
  Future<List<PersonalSpace>> spaces() async {
    final data = await _api.get('/api/personal/spaces');
    return (data as List).cast<Map<String, dynamic>>().map(PersonalSpace.fromJson).toList();
  }

  // Traz todas as informações, prateleiras e caixas de um espaço específico :3
  // API chamada: GET /api/personal/spaces/:id
  Future<PersonalSpace> getSpace(int id) async {
    final data = await _api.get('/api/personal/spaces/$id');
    return PersonalSpace.fromJson(data as Map<String, dynamic>);
  }

  // Cria um novo espaço no sistema (ex: Meu Quarto, Garagem, Guarda-Roupa) (｡•̀ᴗ-)✧
  // API chamada: POST /api/personal/spaces
  Future<PersonalSpace> createSpace(Map<String, dynamic> body) async {
    final data = await _api.post('/api/personal/spaces', body);
    return PersonalSpace.fromJson(data as Map<String, dynamic>);
  }

  // Atualiza as propriedades e objetos de um espaço existente (*¯︶¯*)
  // API chamada: PUT /api/personal/spaces/:id
  Future<PersonalSpace> updateSpace(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/api/personal/spaces/$id', body);
    return PersonalSpace.fromJson(data as Map<String, dynamic>);
  }

  // Manda um espaço para o arquivo morto temporariamente (TwT)
  // API chamada: POST /api/personal/spaces/:id/archive
  Future<void> archiveSpace(int id, int version) =>
      _api.post('/api/personal/spaces/$id/archive', {'version': version});

  // Traz o espaço de volta do arquivo morto para a visualização ativa! ヽ(>∀<☆)ノ
  // API chamada: POST /api/personal/spaces/:id/restore
  Future<void> restoreSpace(int id, int version) =>
      _api.post('/api/personal/spaces/$id/restore', {'version': version});

  // O detetive do sistema! Você digita "Onde guardei meu passaporte?" e a IA te diz exatamente onde tá! (o^▽^o)
  // API chamada: POST /api/personal/find
  Future<PersonalFindAnswer> findBelongings(String question) async {
    final data = await _api.post('/api/personal/find', {'question': question});
    return PersonalFindAnswer.fromJson(data as Map<String, dynamic>);
  }

  // Puxa a foto em base64 de um móvel ou objeto específico do espaço :3
  // API chamada: GET /api/personal/spaces/:spaceId/objects/:objectId/photo
  Future<String?> objectPhoto(int spaceId, String objectId) async {
    final data = await _api.get('/api/personal/spaces/$spaceId/objects/$objectId/photo');
    if (data is Map<String, dynamic>) {
      return data['photo'] as String?;
    }
    return null;
  }

  // Puxa a foto em base64 do pertence que você guardou dentro da gaveta :3
  // API chamada: GET /api/personal/spaces/:spaceId/belongings/:itemId/photo
  Future<String?> belongingPhoto(int spaceId, String itemId) async {
    final data = await _api.get('/api/personal/spaces/$spaceId/belongings/$itemId/photo');
    if (data is Map<String, dynamic>) {
      return data['photo'] as String?;
    }
    return null;
  }

  // Move um pertence de um lugar para o outro no seu inventário pessoal! (✿◠‿◠)
  // API chamada: POST /api/personal/spaces/:spaceId/belongings/:itemId/move
  Future<void> moveBelonging(int spaceId, String itemId, Map<String, dynamic> body) =>
      _api.post('/api/personal/spaces/$spaceId/belongings/$itemId/move', body);
}
