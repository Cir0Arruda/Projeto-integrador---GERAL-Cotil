// ============================================================================
// ★ REPOSITÓRIO DE CONTAS & AUTENTICAÇÃO ★
// Aqui moram as funções que chamam as APIs de autenticação, login,
// cadastro de usuários e o fluxo oficial do Google OAuth (｡•̀ᴗ-)✧
// ============================================================================

import '../core/api_client.dart';
import '../models/account_models.dart';

// Pacotinho fofo que guarda o token JWT e as informações do usuário logado :3
typedef AuthResult = ({String token, UserProfile user});

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  // API: POST /api/auth/login
  // Envia e-mail e senha pro servidor validar e devolver o token de acesso (o^▽^o)
  Future<AuthResult> login(String email, String password) async {
    final data = await _api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return _authResult(data);
  }

  // API: POST /api/auth/register
  // Registra uma nova conta de usuário com seus dados e cria a organização (✿◠‿◠)
  Future<AuthResult> register(Map<String, dynamic> payload) async {
    final data = await _api.post('/api/auth/register', payload);
    return _authResult(data);
  }

  // ==========================================================================
  // ★ API: GET /api/auth/oauth/config (GOOGLE AUTH CONFIG) ★
  // Pergunta pro servidor se o Google OAuth tá ligado e pega o Client ID e Nonce :3
  // O servidor responde se está habilitado pra gente renderizar o botão oficial!
  // ==========================================================================
  Future<OAuthConfig> oauthConfig() async {
    final data = await _api.get('/api/auth/oauth/config');
    return OAuthConfig.fromJson(data as Map<String, dynamic>);
  }

  // ==========================================================================
  // ★ API: POST /api/auth/oauth/google (LOGIN COM GOOGLE) ★
  // Manda a credencial JWT assinada pelo Google pro servidor verificar e logar! (づ｡◕‿‿◕｡)づ
  // ==========================================================================
  Future<AuthResult> loginWithGoogle({required String credential, required String nonce}) async {
    final data = await _api.post('/api/auth/oauth/google', {
      'credential': credential,
      'nonce': nonce,
    });
    return _authResult(data);
  }

  // API: GET /api/workspace/context
  // Descobre se o usuário tá no modo Corporativo ou Pessoal (TwT)
  Future<WorkspaceContext> workspaceContext() async {
    final data = await _api.get('/api/workspace/context');
    return WorkspaceContext.fromJson(data as Map<String, dynamic>);
  }

  // API: PUT /api/workspace/type
  // Alterna o tipo do espaço de trabalho entre corporativo e pessoal :3
  Future<void> setWorkspaceType(String type) =>
      _api.put('/api/workspace/type', {'type': type});

  // API: POST /api/org/complete-setup
  // Finaliza a configuração inicial da organização quando a conta é nova (*¯︶¯*)
  Future<void> completeSetup({required String name}) =>
      _api.post('/api/org/complete-setup', {'name': name});

  // API: GET /api/auth/me
  // Pega o perfil atualizado do usuário logado (nome, e-mail, cargo, foto) (｡•̀ᴗ-)✧
  Future<UserProfile> me() async {
    final data = await _api.get('/api/auth/me');
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  // API: POST /api/auth/logout
  // Avisa o servidor que estamos saindo e encerra a sessão com segurança (;-;)
  Future<void> logout() => _api.post('/api/auth/logout', {});

  // API: PUT /api/auth/profile
  // Atualiza nome ou dados cadastrais do perfil da pessoa :3
  Future<void> updateProfile(Map<String, dynamic> payload) =>
      _api.put('/api/auth/profile', payload);

  // API: PUT /api/auth/profile (avatar_url)
  // Faz o upload da foto de perfil em base64 pro servidor (✿◠‿◠)
  Future<void> updateAvatar(String? dataUri) =>
      _api.put('/api/auth/profile', {'avatar_url': dataUri});

  // API: POST /api/auth/change-password
  // Permite trocar a senha atual por uma nova de forma segura (o^▽^o)
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _api.post('/api/auth/change-password', {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

  // API: GET /api/org/me
  // Pega os dados da empresa/organização (nome, plano, CNPJ, logo) :3
  Future<Organization> organization() async {
    final data = await _api.get('/api/org/me');
    return Organization.fromJson(data as Map<String, dynamic>);
  }

  // API: PUT /api/org/me
  // Atualiza as informações da empresa no sistema (*¯︶¯*)
  Future<void> updateOrganization({String? name, String? cnpj, String? address}) =>
      _api.put('/api/org/me', {
        if (name != null) 'name': name,
        if (cnpj != null) 'cnpj': cnpj,
        if (address != null) 'address': address,
      });

  // API: GET /api/org/units
  // Lista filiais ou unidades de negócio cadastradas na organização (｡•̀ᴗ-)✧
  Future<List<OrgUnit>> units() async {
    final data = await _api.get('/api/org/units');
    return (data as List).cast<Map<String, dynamic>>().map(OrgUnit.fromJson).toList();
  }

  // API: POST /api/org/units
  // Cria uma nova unidade física ou filial para organizar os armazéns :3
  Future<OrgUnit> createUnit({required String code, required String name, String? description}) async {
    final data = await _api.post('/api/org/units', {
      'code': code,
      'name': name,
      if (description != null) 'description': description,
    });
    return OrgUnit.fromJson(data as Map<String, dynamic>);
  }

  // API: DELETE /api/org/units/:id
  // Remove uma unidade do sistema (;-;)
  Future<void> deleteUnit(int id) => _api.delete('/api/org/units/$id');

  // API: GET /api/org/invites
  // Lista convites pendentes enviados por e-mail para novos membros da equipe (TwT)
  Future<List<OrgInvite>> invites() async {
    final data = await _api.get('/api/org/invites');
    return (data as List).cast<Map<String, dynamic>>().map(OrgInvite.fromJson).toList();
  }

  // API: POST /api/org/invites
  // Cria um convite para outra pessoa entrar na mesma organização (づ｡◕‿‿◕｡)づ
  Future<OrgInvite> createInvite({String? email, required String role, int expiresHours = 48}) async {
    final data = await _api.post('/api/org/invites', {
      if (email != null && email.isNotEmpty) 'email': email,
      'role': role,
      'expires_hours': expiresHours,
    });
    return OrgInvite.fromJson(data as Map<String, dynamic>);
  }

  // API: GET /api/org/users
  // Lista todos os usuários que trabalham nessa organização com seus cargos (o^▽^o)
  Future<List<OrgMember>> members() async {
    final data = await _api.get('/api/org/users');
    return (data as List).cast<Map<String, dynamic>>().map(OrgMember.fromJson).toList();
  }

  // API: PUT /api/org/users/:id
  // Altera o cargo ou permissões de um membro da equipe :3
  Future<void> updateMemberRole(int userId, String role) =>
      _api.put('/api/org/users/$userId', {'role': role});

  // Função utilitária que converte a resposta da API no objeto AuthResult (｡•̀ᴗ-)✧
  AuthResult _authResult(dynamic data) {
    final map = data as Map<String, dynamic>;
    return (
      token: map['token'] as String,
      user: UserProfile.fromJson(map['user'] as Map<String, dynamic>),
    );
  }
}
