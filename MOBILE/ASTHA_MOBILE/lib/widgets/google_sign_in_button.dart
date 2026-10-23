// ============================================================================
// ★ BOTÃOZINHO OFICIAL DE LOGIN / CADASTRO COM O GOOGLE ★
// Esse botão conversa com duas rotas de API do nosso servidor:
// 1) GET /api/auth/oauth/config: pergunta se o Google Auth tá ligado e pega o Client ID :3
// 2) POST /api/auth/oauth/google: manda o crachá do Google pra logar a gente! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/session_controller.dart';
import 'dialogs.dart';
import 'google_auth_host.dart';

// O botãozinho lindo que você clica pra entrar ou criar conta com o Google (✿◠‿◠)
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    this.isSignUp = false,
    this.targetWorkspace,
  });

  // Se for true, muda o textinho pra "Criar conta com Google" em vez de "Continuar..."
  final bool isSignUp;
  // Se for pra ir direto pro workspace pessoal (modo usuário comum) :3
  final String? targetWorkspace;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  // Diz se o app tá ocupado conversando com os servidores (gira a rodinha!) (TwT)
  bool _busy = false;

  // Quando o usuário clica no botão, essa função entra em ação! ヽ(>∀<☆)ノ
  Future<void> _handlePress() async {
    if (!kIsWeb) {
      showToast(
        context,
        'O login Google está disponível no Chrome/Edge. Neste aplicativo nativo, use e-mail e senha.',
        error: true,
      );
      return;
    }
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      // 1. Pergunta pro servidor se o Google OAuth tá configuradinho certinho :3
      // Chama a rota GET /api/auth/oauth/config
      final config = await session.fetchOAuthConfig();
      if (!mounted) return;

      // Se o servidor não tiver as chaves do Google cadastradas no .env, avisa a pessoa ;-;
      if (!config.googleEnabled || config.googleNonce == null) {
        showToast(
          context,
          'Login Google disponível após a configuração do administrador no servidor.',
          error: true,
        );
        return;
      }

      // 2. Abre a janelinha oficial do Google pra fazer o login! (｡•̀ᴗ-)✧
      await _openGoogleAuthDialog(
        config.googleClientId ?? '',
        config.googleNonce!,
      );
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não foi possível conectar ao Google.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Janelinha modal onde o botão oficial do Google (GIS) é renderizado :3
  Future<void> _openGoogleAuthDialog(String clientId, String nonce) async {
    final session = context.read<SessionController>();

    final credential = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            GoogleLogo(size: 24),
            SizedBox(width: 10),
            Text('Autenticação Google', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoogleAuthHost(
                clientId: clientId,
                nonce: nonce,
                onCredential: (cred) => Navigator.of(ctx).pop(cred),
              ),
              const SizedBox(height: 12),
              const Text(
                'Escolha sua conta na janela segura do Google para continuar.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    // Only credentials returned by Google Identity Services are accepted here.
    if (credential != null && credential.isNotEmpty && mounted) {
      setState(() => _busy = true);
      try {
        // Dispara a chamada da API POST /api/auth/oauth/google enviando o token JWT do Google!
        // O servidor valida a assinatura com os servidores do Google e cria nossa sessão (｡•̀ᴗ-)✧
        await session.signInWithGoogle(credential: credential, nonce: nonce);
        if (widget.targetWorkspace == 'personal' && mounted) {
          await session.setWorkspaceMode('personal');
        }
      } on ApiException catch (e) {
        // Se a API recusar o token (por exemplo se tiver expirado ou nonce inválido) (TwT)
        if (mounted) showToast(context, e.message, error: true);
      } catch (_) {
        // Se der qualquer outro erro estranho ;-;
        if (mounted) {
          showToast(
            context,
            'Não foi possível concluir o login com Google.',
            error: true,
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F1F1F),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF747775), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: _busy ? null : _handlePress,
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GoogleLogo(size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.isSignUp
                        ? 'Criar conta com Google'
                        : 'Continuar com o Google',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google-g.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}
