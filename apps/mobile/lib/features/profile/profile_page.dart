// ============================================================================
// ★ TELA DE PERFIL DO USUÁRIO (PROFILE_PAGE.DART) ★
// Aqui o usuário visualiza e gerencia os seus dados pessoais e de acesso! (✿◠‿◠)
// 1) Carrega dados da API: GET /api/auth/me e GET /api/account/organization :3
// 2) Permite atualizar nome, telefone e dados: PUT /api/auth/me (｡•̀ᴗ-)✧
// 3) Permite trocar foto de perfil: POST /api/auth/avatar
// 4) Permite alterar senha com segurança e sair da conta (logout)! ヽ(>∀<☆)ノ
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../models/account_models.dart';
import '../../repositories/account_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/user_avatar.dart';
import '../shared/labels.dart';

// Telinha de perfil e configurações de conta do usuário :3
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.read<AccountRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: AsyncView<({UserProfile user, Organization? org})>(
        load: () async {
          final user = await account.me();
          Organization? org;
          try {
            org = await account.organization();
          } on ApiException {
            org = null;
          }
          return (user: user, org: org);
        },
        builder: (context, data) =>
            _ProfileBody(user: data.user, org: data.org),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.user, required this.org});

  final UserProfile user;
  final Organization? org;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _surname = TextEditingController(text: widget.user.surname);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _dob = TextEditingController(text: widget.user.dob);
  late final _gender = TextEditingController(text: widget.user.gender);
  late final _country = TextEditingController(text: widget.user.country);
  late final _company = TextEditingController(text: widget.user.company);
  late final _sector = TextEditingController(text: widget.user.sector);
  late final _positionLabel = TextEditingController(
    text: widget.user.positionLabel,
  );
  late String? _avatar = widget.user.avatarUrl;
  bool _busy = false;
  bool _photoBusy = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _surname,
      _phone,
      _dob,
      _gender,
      _country,
      _company,
      _sector,
      _positionLabel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast(context, 'Informe o nome.', error: true);
      return;
    }
    final account = context.read<AccountRepository>();
    final session = context.read<SessionController>();
    setState(() => _busy = true);
    try {
      await account.updateProfile({
        'name': _name.text.trim(),
        'surname': _surname.text.trim(),
        'phone': _phone.text.trim(),
        'dob': _dob.text.trim(),
        'gender': _gender.text.trim(),
        'country': _country.text.trim(),
        'company': _company.text.trim(),
        'sector': _sector.text.trim(),
        'position_label': _positionLabel.text.trim(),
      });
      await session.refreshUser();
      if (mounted) showToast(context, 'Perfil atualizado.');
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _detectMime(Uint8List bytes) {
    if (bytes.length > 12) {
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45) {
        return 'image/webp';
      }
    }
    return null;
  }

  Future<void> _saveAvatar(String? dataUri) async {
    final account = context.read<AccountRepository>();
    final session = context.read<SessionController>();
    setState(() => _photoBusy = true);
    try {
      await account.updateAvatar(dataUri);
      await session.refreshUser();
      if (!mounted) return;
      setState(() => _avatar = dataUri);
      showToast(
        context,
        dataUri == null ? 'Foto removida.' : 'Foto de perfil atualizada.',
      );
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        showToast(context, 'Não foi possível abrir a galeria.', error: true);
      }
      return;
    }
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = _detectMime(bytes);
    if (!mounted) return;
    if (mime == null) {
      showToast(context, 'Use uma imagem PNG, JPEG ou WebP.', error: true);
      return;
    }
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    if (dataUri.length > 1900000) {
      showToast(
        context,
        'A imagem é muito grande. Escolha uma menor.',
        error: true,
      );
      return;
    }
    await _saveAvatar(dataUri);
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (changed != true || !mounted) return;
    showToast(context, 'Senha alterada. Entre novamente.');
    await context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.org;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  UserAvatar(
                    name: widget.user.displayName,
                    avatarUrl: _avatar,
                    radius: 52,
                  ),
                  if (_photoBusy) const CircularProgressIndicator(),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _photoBusy ? null : _pickPhoto,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(
                      _avatar == null ? 'Adicionar foto' : 'Alterar foto',
                    ),
                  ),
                  if (_avatar != null)
                    TextButton(
                      onPressed: _photoBusy ? null : () => _saveAvatar(null),
                      child: const Text('Remover'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Dados pessoais',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InfoRow(label: 'E-mail', value: widget.user.email),
                InfoRow(label: 'Função', value: roleLabel(widget.user.role)),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _surname,
                  decoration: const InputDecoration(labelText: 'Sobrenome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dob,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Nascimento',
                    hintText: 'AAAA-MM-DD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gender,
                  decoration: const InputDecoration(labelText: 'Gênero'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _country,
                  decoration: const InputDecoration(labelText: 'País'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _company,
                  decoration: const InputDecoration(labelText: 'Empresa'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sector,
                  decoration: const InputDecoration(
                    labelText: 'Setor / Departamento',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _positionLabel,
                  decoration: const InputDecoration(labelText: 'Cargo'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SALVAR ALTERAÇÕES'),
                ),
              ],
            ),
          ),
        ),
        if (org != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Organização',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(label: 'Nome', value: org.name),
                  InfoRow(label: 'Plano', value: org.plan),
                  InfoRow(label: 'E-mail', value: org.email),
                  InfoRow(label: 'Telefone', value: org.phone),
                  InfoRow(label: 'Local', value: org.location),
                  InfoRow(label: 'Espaço', value: org.workspaceType),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'Segurança',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Alterar senha'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _newPassword.text.isEmpty) {
      showToast(context, 'Preencha a senha atual e a nova senha.', error: true);
      return;
    }
    if (_newPassword.text != _confirm.text) {
      showToast(context, 'A confirmação não confere.', error: true);
      return;
    }
    if (!AppConfig.validPassword(_newPassword.text)) {
      showToast(
        context,
        'Use pelo menos 15 caracteres, até 72 bytes, sem senha comum ou repetida.',
        error: true,
      );
      return;
    }
    final account = context.read<AccountRepository>();
    setState(() => _busy = true);
    try {
      await account.changePassword(_current.text, _newPassword.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alterar senha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha atual'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nova senha',
              helperText: 'Pelo menos 15 caracteres e no máximo 72 bytes',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmar nova senha',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
