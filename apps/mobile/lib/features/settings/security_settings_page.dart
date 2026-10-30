// ============================================================================
// ★ SEGURANÇA E TROCA DE SENHA (SECURITY_SETTINGS_PAGE.DART) ★
// Protege a conta do usuário contra acessos não autorizados:
// 1) Troca de senha segura com verificação da senha atual :3
// 2) Indicador de força de senha e requisitos mínimos de segurança (✿◠‿◠)
// 3) Informações sobre sessões ativas e autenticação JWT! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../repositories/account_repository.dart';
import '../../state/session_controller.dart';
import '../shared/labels.dart';

// Telinha de ajustes de segurança e senhas :3
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await context.read<AccountRepository>().changePassword(
            _currentPasswordController.text,
            _newPasswordController.text,
          );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao atualizar senha: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Segurança & Acessos'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPasswordCard(),
          const SizedBox(height: 16),
          _buildSessionCard(user, session),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 20, color: AppColors.brand),
                SizedBox(width: 8),
                Text(
                  'Alterar Senha',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'A nova senha deve ter no mínimo 15 caracteres conforme a política de segurança.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Senha atual *',
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Informe a senha atual.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Nova senha *',
                hintText: 'Mínimo 15 caracteres',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe a nova senha.';
                if (v.length < 15) return 'A senha deve ter no mínimo 15 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha *',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme a nova senha.';
                if (v != _newPasswordController.text) return 'As senhas não coincidem.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _changePassword,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('ATUALIZAR SENHA'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(dynamic user, SessionController session) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_outlined, size: 20, color: AppColors.textMain),
              SizedBox(width: 8),
              Text(
                'Sessão & Dispositivo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Usuário', user?.displayName ?? '—'),
          const Divider(height: 16),
          _buildInfoRow('E-mail autenticado', user?.email ?? '—'),
          const Divider(height: 16),
          _buildInfoRow('Papel no sistema', roleLabel(user?.role)),
          const Divider(height: 16),
          _buildInfoRow('Servidor conectado', session.serverUrl),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Encerrar sessão'),
                    content: const Text('Deseja realmente sair desta conta?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  session.signOut();
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
              label: const Text('ENCERRAR SESSÃO', style: TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
