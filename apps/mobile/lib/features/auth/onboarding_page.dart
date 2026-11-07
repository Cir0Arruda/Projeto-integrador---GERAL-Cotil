import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/account_models.dart';
import '../../repositories/account_repository.dart';
import '../../state/session_controller.dart';

/// Authenticated signup completion. Never registers a second account or chooses
/// the workspace type silently after an OAuth callback.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _profileForm = GlobalKey<FormState>(),
      _workspaceForm = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _surname = TextEditingController(),
      _phone = TextEditingController(),
      _country = TextEditingController(),
      _workspace = TextEditingController(),
      _cnpj = TextEditingController(),
      _invite = TextEditingController();
  Organization? _organization;
  String? _type, _error;
  int _step = 0;
  bool _loading = true, _saving = false, _usingInvite = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>(), user = session.user;
    _type = session.setupPreference;
    _name.text = user?.name ?? '';
    _surname.text = user?.surname ?? '';
    _phone.text = user?.phone ?? '';
    _country.text = user?.country ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final org = await context.read<AccountRepository>().organization();
      if (!mounted) return;
      _workspace.text =
          RegExp(
            r'^Organiza(?:ção|Ã§Ã£o) de ',
            caseSensitive: false,
          ).hasMatch(org.name)
          ? ''
          : org.name;
      _cnpj.text = org.cnpj ?? '';
      setState(() {
        _organization = org;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível carregar o cadastro. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<SessionController>().refreshUser();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível atualizar a sessão. Entre novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    if (_saving || _type == null || _organization == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().completeOnboarding(
        type: _type!,
        name: _name.text,
        surname: _surname.text,
        phone: _phone.text,
        country: _country.text,
        workspaceName: _workspace.text,
        organization: _organization!,
        cnpj: _type == 'corporate' ? _cnpj.text : null,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível confirmar a conclusão. Atualize a sessão antes de tentar novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _join() async {
    final code = _invite.text.trim();
    if (!RegExp(r'^[a-fA-F0-9]{8}$').hasMatch(code)) {
      setState(() => _error = 'Informe o código de convite de 8 caracteres.');
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().joinWorkspace(code);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível confirmar a entrada. Atualize a sessão ou entre novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_step == 0 && _type == null) return;
    if (_step == 1 && !_profileForm.currentState!.validate()) return;
    if (_step == 2 && !_workspaceForm.currentState!.validate()) return;
    if (_step == 3) {
      _finish();
      return;
    }
    setState(() {
      _step++;
      _error = null;
    });
  }

  Widget _choice(String value, String title, String detail, IconData icon) {
    final selected = _type == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(18),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        onPressed: _saving ? null : () => setState(() => _type = value),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(detail),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_outline),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Como você pretende usar o ASTHA?',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _choice(
              'personal',
              'Pessoal',
              'Espaços 3D, pertences, agenda e organização pessoal.',
              Icons.home_outlined,
            ),
            _choice(
              'corporate',
              'Corporativo',
              'Estoque, equipe, ativos, manutenção e relatórios.',
              Icons.business_outlined,
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _usingInvite = !_usingInvite;
                      _error = null;
                    }),
              child: Text(
                _usingInvite
                    ? 'Criar meu próprio espaço'
                    : 'Já tenho um convite para uma organização',
              ),
            ),
            if (_usingInvite) ...[
              TextField(
                controller: _invite,
                enabled: !_saving,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código de convite',
                ),
              ),
              OutlinedButton(
                onPressed: _saving ? null : _join,
                child: const Text('Entrar com convite'),
              ),
            ],
          ],
        );
      case 1:
        return Form(
          key: _profileForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sobre você',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                maxLength: 100,
                autofillHints: const [AutofillHints.givenName],
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe seu nome.' : null,
              ),
              TextFormField(
                controller: _surname,
                enabled: !_saving,
                maxLength: 100,
                autofillHints: const [AutofillHints.familyName],
                decoration: const InputDecoration(
                  labelText: 'Sobrenome (opcional)',
                ),
              ),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                ),
              ),
              TextFormField(
                controller: _country,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'País (opcional)'),
              ),
              const Text(
                'O e-mail de acesso é o da conta com a qual você entrou.',
              ),
            ],
          ),
        );
      case 2:
        return Form(
          key: _workspaceForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _type == 'personal' ? 'Seu espaço pessoal' : 'Sua empresa',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _workspace,
                enabled: !_saving,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: _type == 'personal'
                      ? 'Nome do espaço'
                      : 'Nome da empresa',
                ),
                validator: (v) =>
                    v == null ||
                        v.trim().isEmpty ||
                        RegExp(
                          r'^Organiza(?:ção|Ã§Ã£o) de ',
                          caseSensitive: false,
                        ).hasMatch(v.trim())
                    ? 'Escolha um nome para o workspace.'
                    : null,
              ),
              if (_type == 'corporate')
                TextFormField(
                  controller: _cnpj,
                  enabled: !_saving,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'CNPJ (opcional)',
                  ),
                ),
            ],
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Revise seu cadastro',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Text(
              'Tipo de uso: ${_type == 'personal' ? 'Pessoal' : 'Corporativo'}',
            ),
            const SizedBox(height: 12),
            Text('Nome: ${_name.text.trim()} ${_surname.text.trim()}'),
            const SizedBox(height: 12),
            Text('Workspace: ${_workspace.text.trim()}'),
            const SizedBox(height: 18),
            const Text(
              'Seus dados serão salvos somente ao concluir. Você poderá personalizar seu perfil depois.',
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>(),
        owner = session.user?.role == 'superadmin';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concluir cadastro'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => session.signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading || _saving) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(liveRegion: true, child: Text(_error!)),
                    ),
                  if (!_loading && _organization == null)
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente'),
                    ),
                  if (!_loading && _organization != null) ...[
                    if (!owner) ...[
                      const Text(
                        'O responsável pela organização precisa concluir a configuração inicial.',
                      ),
                      OutlinedButton(
                        onPressed: _saving ? null : _refresh,
                        child: const Text('Atualizar sessão'),
                      ),
                    ] else ...[
                      Text('Etapa ${_step + 1} de 4'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: (_step + 1) / 4),
                      const SizedBox(height: 24),
                      _content(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (_step > 0) ...[
                            OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _step--),
                              child: const Text('Voltar'),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _saving || (_step == 0 && _type == null)
                                  ? null
                                  : _next,
                              child: Text(
                                _saving
                                    ? 'Salvando…'
                                    : _step == 3
                                    ? 'Concluir cadastro'
                                    : 'Continuar',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null)
                        TextButton(
                          onPressed: _saving ? null : _refresh,
                          child: const Text('Atualizar sessão'),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _surname,
      _phone,
      _country,
      _workspace,
      _cnpj,
      _invite,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
