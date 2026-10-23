// ============================================================================
// ★ TELA DE CADASTRO EM ETAPAS (REGISTER_PAGE.DART) ★
// Aqui o novo usuário cria a conta dele no RAVEN ASTHA! (✿◠‿◠)
// Funciona como um assistente de 4 etapas:
// 1) Escolhe o tipo de conta (Corporativo ou Pessoal) ou usa o Google :3
// 2) Preenche os dados pessoais (nome, e-mail, telefone, etc)
// 3) Cria uma senha forte e segura (｡•̀ᴗ-)✧
// 4) Dispara a API POST /api/auth/register e comemora com tela de sucesso! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/config.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/session_controller.dart';
import '../../widgets/cards.dart';
import '../../widgets/google_sign_in_button.dart';

// Telinha interativa de cadastro com passo a passo :3
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Guarda em qual passo o usuário tá (1, 2, 3 ou 4) (o^▽^o)
  int _currentStep = 1;
  // Tipo de conta selecionada ('corporate' ou 'personal') :3
  String? _selectedType;

  // Chaves dos formulários para validação de campos obrigatórios
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  // Controladores dos textinhos digitados pelo usuário (づ｡◕‿‿◕｡)づ
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  final _invite = TextEditingController();
  String _gender = '';

  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hiddenPassword = true;
  bool _hiddenConfirm = true;

  // Mostra a rodinha de carregando quando tá conversando com o servidor (TwT)
  bool _busy = false;
  // Guarda qualquer erro que a API devolver (ex: email já cadastrado) ;-;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _dob.dispose();
    _country.dispose();
    _phone.dispose();
    _invite.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // Avança ou volta os passinhos do cadastro :3
  void _nextStep(int step) {
    setState(() {
      _currentStep = step;
      _error = null;
    });
  }

  // Abre o calendário nativo pro usuário escolher o aniversário de forma bem fácil (✿◠‿◠)
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() => _dob.text = '$y-$m-$d');
    }
  }

  // ==========================================================================
  // DISPARO DA API DE REGISTRO! (POST /api/auth/register)
  // Junta todos os dadinhos preenchidos e envia pro servidor criar a conta :3
  // ==========================================================================
  Future<void> _submitRegistration() async {
    // Confere se as senhas coincidem e se o formulário tá certinho (｡•̀ᴗ-)✧
    if (!_formKeyStep3.currentState!.validate()) return;
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'As senhas não conferem.');
      return;
    }

    // Separa o nome em Primeiro Nome e Sobrenome bonitinho
    final rawName = _fullName.text.trim();
    final parts = rawName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final surname = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final session = context.read<SessionController>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Chama a API POST /api/auth/register através do SessionController! (づ｡◕‿‿◕｡)づ
      await session.signUp({
        'name': firstName,
        if (surname.isNotEmpty) 'surname': surname,
        'email': _email.text.trim(),
        'password': _password.text,
        if (_dob.text.isNotEmpty) 'dob': _dob.text.trim(),
        if (_gender.isNotEmpty) 'gender': _gender,
        if (_country.text.isNotEmpty) 'country': _country.text.trim(),
        if (_phone.text.isNotEmpty) 'phone': _phone.text.trim(),
        if (_invite.text.isNotEmpty) 'invite_code': _invite.text.trim(),
      });

      // Se escolheu conta pessoal, salva a preferência pro app abrir no modo pessoal :3
      if (_selectedType == 'personal') {
        try {
          await session.setWorkspaceMode('personal');
        } catch (_) {}
      }

      // Vai pro passo 4: Tela de celebração e boas-vindas! ヽ(>∀<☆)ノ
      setState(() {
        _currentStep = 4;
      });
    } on ApiException catch (error) {
      // Se a API recusar (tipo email repetido ou senha fraca), avisa a pessoa (TwT)
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      // Erro inesperado de conexão ;-;
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível concluir o cadastro. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro RAVEN ASTHA'),
        leading: _currentStep > 1 && _currentStep < 4
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _nextStep(_currentStep - 1),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Brand()),
                  const SizedBox(height: 24),
                  if (_currentStep < 4) ...[
                    LinearProgressIndicator(
                      value: _currentStep / 3,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.brand,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (_currentStep == 1) _buildStep1(),
                  if (_currentStep == 2) _buildStep2(),
                  if (_currentStep == 3) _buildStep3(),
                  if (_currentStep == 4) _buildStep4(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoogleSignInButton(isSignUp: true, targetWorkspace: _selectedType),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ou cadastre com formulário',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Como você pretende usar o ASTHA?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Escolha o plano que melhor se adapta a você.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                type: 'personal',
                title: 'Pessoal',
                subtitle: 'Uso independente para pequenos estoques e casa.',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildTypeCard(
                type: 'corp',
                title: 'Corporativo',
                subtitle: 'Para empresas, colaborativo e multi-armazéns.',
                icon: Icons.business_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _selectedType == null ? null : () => _nextStep(2),
          child: const Text('CONTINUAR'),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.brand : Colors.grey.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.brandText : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sobre você',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Precisamos de algumas informações básicas para o seu perfil.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome completo *',
              hintText: 'Ex.: João da Silva',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Informe seu nome completo'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail *',
              hintText: 'voce@exemplo.com',
            ),
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Informe um e-mail válido'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dob,
            readOnly: true,
            onTap: _pickDate,
            decoration: const InputDecoration(
              labelText: 'Data de nascimento',
              hintText: 'AAAA-MM-DD',
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gênero'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Prefiro não informar')),
              DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
              DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
              DropdownMenuItem(value: 'Outro', child: Text('Outro')),
              DropdownMenuItem(
                value: 'Prefiro não dizer',
                child: Text('Prefiro não dizer'),
              ),
            ],
            onChanged: (val) => setState(() => _gender = val ?? ''),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _country,
                  decoration: const InputDecoration(
                    labelText: 'País / região',
                    hintText: 'Ex.: Brasil',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '(00) 00000-0000',
                  ),
                ),
              ),
            ],
          ),
          if (_selectedType == 'corp') ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _invite,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de convite (opcional)',
                helperText: 'Para ingressar em organização existente',
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (_formKeyStep2.currentState!.validate()) {
                _nextStep(3);
              }
            },
            child: const Text('AVANÇAR'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _nextStep(1),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _formKeyStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Segurança da Conta',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crie uma senha forte para proteger seus dados.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _password,
            obscureText: _hiddenPassword,
            decoration: InputDecoration(
              labelText: 'Senha *',
              helperText: 'Pelo menos 15 caracteres e no máximo 72 bytes',
              suffixIcon: IconButton(
                icon: Icon(
                  _hiddenPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _hiddenPassword = !_hiddenPassword),
              ),
            ),
            validator: (value) =>
                (value == null || !AppConfig.validPassword(value))
                ? 'Use 15 caracteres ou mais, até 72 bytes, sem senha comum ou repetida'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPassword,
            obscureText: _hiddenConfirm,
            decoration: InputDecoration(
              labelText: 'Confirmar senha *',
              suffixIcon: IconButton(
                icon: Icon(
                  _hiddenConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _hiddenConfirm = !_hiddenConfirm),
              ),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Confirme sua senha' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submitRegistration,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('CRIAR CONTA'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => _nextStep(2),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(
          Icons.check_circle_outline,
          size: 72,
          color: Color(0xFF10B981),
        ),
        const SizedBox(height: 20),
        const Text(
          'Conta Criada com Sucesso!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedType == 'personal'
              ? 'Seu workspace pessoal foi iniciado. Você já pode organizar seus espaços e pertences.'
              : 'Agora vamos concluir a configuração do seu workspace corporativo.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text('ACESSAR WORKSPACE'),
        ),
      ],
    );
  }
}
