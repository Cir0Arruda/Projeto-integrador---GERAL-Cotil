// ============================================================================
// ★ TELA DE LOGIN DO RAVEN ASTHA (LOGIN_PAGE.DART) ★
// Permite entrar com E-mail + Senha (chamando POST /api/auth/login)
// ou com um clique usando o botão do Google OAuth! :3
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/session_controller.dart';
import '../../widgets/cards.dart';
import '../../widgets/connection_status_badge.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/google_sign_in_button.dart';
import 'register_page.dart';

// Telinha de login com visual minimalista e elegante (✿◠‿◠)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Quando a pessoa clica no botão "Entrar", chama a API do backend! (｡•̀ᴗ-)✧
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Dispara POST /api/auth/login com e-mail e senha pra pegar o token JWT :3
      await session.signIn(_email.text, _password.text);
    } on ApiException catch (error) {
      // Se a senha tiver errada ou usuário não existir, mostra o alerta (TwT)
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final message = _error ?? session.notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Brand(),
                        // Mostra o status do servidor em tempo real (Online / Buscando / Outra rede) :3
                        const ConnectionStatusBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Bem-vindo de volta',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Entre na sua conta para continuar sua operação.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    const GoogleSignInButton(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou entre com seu e-mail',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (message != null) _ErrorBanner(message: message),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                          ? 'Informe um e-mail válido'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidden,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _hidden = !_hidden),
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Informe a senha'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('ENTRAR'),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterPage(),
                        ),
                      ),
                      child: const Text('Ainda não tem uma conta? Criar conta'),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => showServerDialog(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.storage_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                session.serverUrl,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
