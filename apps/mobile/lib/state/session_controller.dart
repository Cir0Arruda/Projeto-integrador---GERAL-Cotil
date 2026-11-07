// ============================================================================
// ★ O CÉREBRO DA SESSÃO E LOGIN (SESSION_CONTROLLER.DART) ★
// Esse cara controla quem tá logado, os crachás digitais (tokens JWT),
// se o usuário tá no modo Corporativo ou Pessoal, e restaura o login quando
// o aplicativo é aberto! (✿◠‿◠)
// Conecta com todas as rotas de autenticação da nossa API! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/offline_store.dart';
import '../core/offline_coordinator.dart';
import '../core/connection_service.dart';
import '../core/session_store.dart';
import '../core/background_sync.dart';
import '../models/account_models.dart';
import '../repositories/account_repository.dart';

// Os três possíveis estados da sessão :3
enum SessionStatus {
  restoring, // Checando a gavetinha de memória... aguenta um pouquinho! (TwT)
  signedOut, // Usuário deslogado (mostra tela de login) ;-;
  signedIn, // Logadíssimo com sucesso! ヽ(>∀<☆)ノ
}

// O controlador central de sessão que notifica todas as telas quando algo muda :3
class SessionController extends ChangeNotifier {
  SessionController(this._store, this.api) : _account = AccountRepository(api) {
    api.onUnauthorized = _expire;
  }

  final SessionStore _store;
  final ApiClient api;
  final AccountRepository _account;

  //serviço de diagnóstico e auto-reconexão multi-redes :3
  late final ConnectionService connectionService = ConnectionService(
    initialUrl: api.baseUrl,
    onServerChanged: (newUrl) {
      api.baseUrl = newUrl;
      notifyListeners();
    },
  );

  SessionStatus _status = SessionStatus.restoring;
  UserProfile? _user;
  String? _notice;
  String _workspaceType = 'corporate';
  bool _setupDone = true;
  String? _setupPreference;

  SessionStatus get status => _status;
  UserProfile? get user => _user;
  String? get notice => _notice;
  String get serverUrl => api.baseUrl;
  String get workspaceType => _workspaceType;
  bool get isPersonal => _workspaceType == 'personal';
  bool get needsSetup => !_setupDone;
  String? get setupPreference => _setupPreference;

  Future<void> restore() async {
    final savedUrl = await _store.readServerUrl();
    api.baseUrl = savedUrl;

    await connectionService.checkCurrent();

    final token = await _store.readToken();
    if (token == null) {
      _setStatus(SessionStatus.signedOut);
      return;
    }
    api.token = token;
    try {
      _user = await _account.me();
      await _syncWorkspaceContext();
      await _prepareOffline();
      _setStatus(SessionStatus.signedIn);
    } on ApiException catch (error) {
      if (!kIsWeb && (error.status == 0 || error.status >= 500)) {
        final identity = await _store.offlineIdentity(token);
        if (identity != null) {
          _user = UserProfile.fromJson(
            Map<String, dynamic>.from(identity['user']),
          );
          _workspaceType = identity['mode'] == 'personal'
              ? 'personal'
              : 'corporate';
          // Preserve legacy encrypted offline identities; online context is
          // authoritative. New incomplete accounts never enable offline mode.
          _setupDone = identity['user']['setup_done'] != false;
          if (await _prepareOffline(remember: false)) {
            _notice =
                'Usando registros locais. Alterações ficam pendentes até confirmação da API.';
            _setStatus(SessionStatus.signedIn);
            return;
          }
        }
      }
      if (error.status == 401) await _store.clearToken();
      api.token = null;
      _setStatus(SessionStatus.signedOut);
    }
  }

  Future<void> signIn(String email, String password) async {
    final result = await _account.login(email.trim(), password);
    await _accept(result);
  }

  Future<void> signUp(
    Map<String, dynamic> payload, {
    String? targetWorkspace,
  }) async {
    final result = await _account.register(payload);
    await _accept(result, setupPreference: targetWorkspace);
  }

  Future<OAuthConfig> fetchOAuthConfig() => _account.oauthConfig();

  Future<void> signInWithGoogle({
    required String credential,
    required String nonce,
    String? targetWorkspace,
  }) async {
    final result = await _account.loginWithGoogle(
      credential: credential,
      nonce: nonce,
    );
    await _accept(result, setupPreference: targetWorkspace);
  }

  Future<void> setWorkspaceMode(String type) async {
    await _account.setWorkspaceType(type);
    _workspaceType = type;
    await _prepareOffline();
    notifyListeners();
  }

  Future<void> _syncWorkspaceContext() async {
    final ctx = await _account.workspaceContext();
    _workspaceType = ctx.type;
    _setupDone = ctx.setupDone;
    if (needsSetup) api.detachOffline();
  }

  Future<void> completeOnboarding({
    required String type,
    required String name,
    required String surname,
    required String phone,
    required String country,
    required String workspaceName,
    required Organization organization,
    String? cnpj,
  }) async {
    if (!needsSetup || !['personal', 'corporate'].contains(type)) {
      throw const ApiException(
        'A configuração mudou. Atualize a sessão antes de continuar.',
      );
    }
    if (organization.id != null && organization.id != _user?.orgId) {
      throw const ApiException(
        'A sessão mudou. Entre novamente antes de concluir o cadastro.',
      );
    }
    final currentContext = await _account.workspaceContext();
    if (currentContext.setupDone) {
      await refreshUser();
      return;
    }
    final currentOrganization = await _account.organization();
    await _account.setWorkspaceType(type);
    await _account.updateProfile({
      'name': name.trim(),
      'surname': surname.trim(),
      'phone': phone.trim(),
      'country': country.trim(),
    });
    await _account.saveSetupOrganization(
      currentOrganization,
      name: workspaceName.trim(),
      cnpj: cnpj,
    );
    await _account.completeSetup();
    await refreshUser();
    if (needsSetup) {
      throw const ApiException(
        'A API ainda não confirmou a conclusão do cadastro. Tente atualizar a sessão.',
      );
    }
    _setupPreference = null;
    await _prepareOffline();
    notifyListeners();
  }

  Future<void> joinWorkspace(String code) async {
    final token = await _account.joinWorkspace(code);
    // The server atomically moved this user and revoked the old session.
    api.token = token;
    await _store.writeToken(token);
    await refreshUser();
    _setupPreference = null;
    await _prepareOffline();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _account.logout();
    } on ApiException {
      _notice = null;
    }
    await _clear();
  }

  Future<void> refreshUser() async {
    _user = await _account.me();
    await _syncWorkspaceContext();
    notifyListeners();
  }

  Future<void> updateServer(String url) async {
    final normalized = AppConfig.normalizeServerUrl(url);
    if (normalized != api.baseUrl) await _clear();
    api.baseUrl = normalized;
    await _store.writeServerUrl(api.baseUrl);
    await connectionService.setServerManually(url);
    notifyListeners();
  }

  Future<void> _accept(AuthResult result, {String? setupPreference}) async {
    await _store.writeToken(result.token);
    api.token = result.token;
    _user = result.user;
    _notice = null;
    try {
      await _syncWorkspaceContext();
      // OAuth returns a minimal identity. Resume the saved profile rather than
      // replacing an unfinished signup's surname/phone/country with blanks.
      if (needsSetup) _user = await _account.me();
      _setupPreference =
          needsSetup && ['personal', 'corporate'].contains(setupPreference)
          ? setupPreference
          : null;
      await _prepareOffline();
      _setStatus(SessionStatus.signedIn);
    } catch (_) {
      await _clear();
      rethrow;
    }
  }

  Future<bool> _prepareOffline({bool remember = true}) async {
    if (needsSetup) return false;
    final user = _user, sessionToken = api.token, origin = api.baseUrl;
    if (kIsWeb || user == null || user.orgId == null || sessionToken == null) {
      return false;
    }
    try {
      if (remember) {
        await _store.rememberIdentity(sessionToken, {
          'id': user.id,
          'name': user.name,
          'surname': user.surname,
          'email': user.email,
          'role': user.role,
          'org_id': user.orgId,
          'org_name': user.orgName,
          'setup_done': _setupDone,
        }, _workspaceType);
      }
      final identity = await _store.offlineIdentity(sessionToken);
      if (identity == null) return false;
      final store = await OfflineStore.open(
        origin: origin,
        org: user.orgId!,
        userId: user.id,
      );
      if (api.token != sessionToken || api.baseUrl != origin) {
        await store.close();
        return false;
      }
      final controller = OfflineCoordinator(store, (
        method,
        path, {
        query,
        body,
      }) {
        if (api.token != sessionToken || api.baseUrl != origin) {
          throw const ApiException('Sessão alterada.', status: 401);
        }
        return api.remote(method, path, query: query, body: body);
      });
      api.attachOffline(
        controller,
        DateTime.fromMillisecondsSinceEpoch(identity['until']),
      );
      try {
        await BackgroundSync.schedule();
      } catch (_) {
        _notice =
            'Os registros offline estão ativos. A sincronização automática em segundo plano não pôde ser agendada.';
        controller.notice = _notice;
        await controller.refresh();
      }
      return true;
    } catch (_) {
      _notice =
          'A sessão está ativa, mas não foi possível habilitar os registros offline.';
      return false;
    }
  }

  Future<void> _clear() async {
    api.detachOffline();
    api.token = null;
    _user = null;
    _setupDone = false;
    _setupPreference = null;
    await _store.clearToken();
    try {
      await BackgroundSync.cancel();
    } catch (_) {}
    _setStatus(SessionStatus.signedOut);
  }

  void _expire() {
    _notice = 'Sua sessão expirou. Entre novamente.';
    _clear();
  }

  void _setStatus(SessionStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    connectionService.dispose();
    api.close();
    super.dispose();
  }
}
