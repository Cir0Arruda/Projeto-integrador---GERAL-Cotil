import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _emailAvailable = false, _loading = true, _busy = false, _done = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _options();
  }

  Future<void> _options() async {
    try {
      final options = await context.read<ApiClient>().remote(
        'GET',
        '/api/account/recovery-options',
      );
      if (mounted) {
        setState(
          () => _emailAvailable =
              options is Map && options['emailRecoveryAvailable'] == true,
        );
      }
    } on ApiException {
      // Saved codes remain available when SMTP or the options endpoint is absent.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateEmail(String? value) =>
      value == null ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? 'Informe um e-mail válido.'
      : null;

  String _responseMessage(dynamic result) {
    if (result is! Map || result['message'] is! String) {
      throw const ApiException('Resposta inválida da API. Tente novamente.');
    }
    return result['message'] as String;
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    final error = _validateEmail(_email.text);
    if (error != null) {
      setState(() => _notice = error);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await context.read<ApiClient>().remote(
        'POST',
        '/api/account/recover/email',
        body: {'email': _email.text.trim()},
      );
      final message = _responseMessage(result);
      if (mounted) {
        setState(() => _notice = message);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recover() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await context.read<ApiClient>().remote(
        'POST',
        '/api/account/recover',
        body: {
          'email': _email.text.trim(),
          'code': _code.text.trim(),
          'new_password': _password.text,
        },
      );
      final message = _responseMessage(result);
      if (mounted) {
        setState(() {
          _done = true;
          _notice = message;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } finally {
      if (mounted) {
        _code.clear();
        _password.clear();
        _confirmation.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar acesso')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Use um código salvo ou recebido por e-mail.'),
                  const SizedBox(height: 20),
                  if (_busy || _loading) const LinearProgressIndicator(),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(liveRegion: true, child: Text(_notice!)),
                    ),
                  if (!_done) ...[
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      maxLength: 254,
                      decoration: const InputDecoration(
                        labelText: 'E-mail da conta',
                      ),
                      validator: _validateEmail,
                    ),
                    if (_emailAvailable) ...[
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _requestCode,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Enviar código por e-mail'),
                      ),
                      const Text(
                        'O código enviado por e-mail vale por 15 minutos. Verifique também o spam.',
                      ),
                    ] else if (!_loading)
                      const Text(
                        'O envio por e-mail está indisponível. Use um código salvo.',
                      ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Código de recuperação',
                      ),
                      validator: (v) =>
                          RegExp(r'^[\w-]{22}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Informe o código de 22 caracteres.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Nova senha',
                      ),
                      validator: (v) =>
                          v == null ||
                              v.runes.length < 15 ||
                              utf8.encode(v).length > 72
                          ? 'Use pelo menos 15 caracteres, até 72 bytes.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmation,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova senha',
                      ),
                      validator: (v) => v == _password.text
                          ? null
                          : 'A confirmação da senha não corresponde.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _recover,
                      child: const Text('Redefinir senha'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Todas as sessões e códigos anteriores serão invalidados. Contas Google ou Microsoft devem recuperar o acesso no próprio provedor.',
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Voltar ao login'),
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
