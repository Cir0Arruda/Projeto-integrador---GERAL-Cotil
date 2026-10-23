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

  SessionStatus get status => _status;
  UserProfile? get user => _user;
  String? get notice => _notice;
  String get serverUrl => api.baseUrl;
  String get workspaceType => _workspaceType;
  bool get isPersonal => _workspaceType == 'personal';

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
    await _accept(result);
    if (targetWorkspace == 'personal') {
      await setWorkspaceMode('personal');
      try {
        await _account.completeSetup(name: 'Meu Espaço');
      } catch (_) {}
    }
  }

  Future<OAuthConfig> fetchOAuthConfig() => _account.oauthConfig();

  Future<void> signInWithGoogle({
    required String credential,
    required String nonce,
  }) async {
    final result = await _account.loginWithGoogle(
      credential: credential,
      nonce: nonce,
    );
    await _accept(result);
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

  Future<void> _accept(AuthResult result) async {
    await _store.writeToken(result.token);
    api.token = result.token;
    _user = result.user;
    _notice = null;
    try {
      await _syncWorkspaceContext();
      await _prepareOffline();
      _setStatus(SessionStatus.signedIn);
    } catch (_) {
      await _clear();
      rethrow;
    }
  }

  Future<bool> _prepareOffline({bool remember = true}) async {
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
    await _store.clearToken();
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
