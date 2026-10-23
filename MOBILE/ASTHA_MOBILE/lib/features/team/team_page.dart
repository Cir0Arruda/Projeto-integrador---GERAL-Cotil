// ============================================================================
// ★ GESTÃO DE EQUIPE E CONVITES (TEAM_PAGE.DART) ★
// Gerencie todos os colegas de trabalho do seu armazém:
// 1) Lista de membros ativos com cargos (admin, gerente, operador) :3
// 2) Gerador de convites com código e validade para novos colaboradores (✿◠‿◠)
// 3) Permite revogar acessos ou trocar papéis de segurança! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/account_models.dart';
import '../../repositories/account_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';
import '../../widgets/user_avatar.dart';
import '../shared/labels.dart';

// Telinha onde você cuida de quem entra e quem trabalha na sua empresa :3
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openInviteDialog() async {
    final emailCtrl = TextEditingController();
    String selectedRole = 'operator';
    int expiresHours = 48;
    final formKey = GlobalKey<FormState>();

    final createdInvite = await showDialog<OrgInvite?>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Convidar para o workspace', style: TextStyle(fontWeight: FontWeight.w700)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'E-mail (opcional)',
                          hintText: 'Apenas esta pessoa poderá usar',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Papel atribuído *'),
                        items: const [
                          DropdownMenuItem(value: 'viewer', child: Text('Visualizador')),
                          DropdownMenuItem(value: 'operator', child: Text('Operador')),
                          DropdownMenuItem(value: 'manager', child: Text('Gerente')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedRole = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: expiresHours,
                        decoration: const InputDecoration(labelText: 'Validade do convite *'),
                        items: const [
                          DropdownMenuItem(value: 24, child: Text('24 horas')),
                          DropdownMenuItem(value: 48, child: Text('48 horas')),
                          DropdownMenuItem(value: 72, child: Text('3 dias')),
                          DropdownMenuItem(value: 168, child: Text('7 dias')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => expiresHours = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(null),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final invite = await context.read<AccountRepository>().createInvite(
                            email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            role: selectedRole,
                            expiresHours: expiresHours,
                          );
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(invite);
                    } catch (e) {
                      if (dialogCtx.mounted) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(content: Text('Erro ao gerar convite: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    }
                  },
                  child: const Text('Gerar convite'),
                ),
              ],
            );
          },
        );
      },
    );

    emailCtrl.dispose();

    if (createdInvite != null && mounted) {
      setState(() => _revision++);
      _showInviteCodeDialog(createdInvite);
    }
  }

  void _showInviteCodeDialog(OrgInvite invite) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convite Criado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compartilhe o código de convite abaixo:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      invite.code,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copiar código',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: invite.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado para a área de transferência.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Concluído'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeMemberRole(OrgMember member) async {
    final canEdit = context.read<SessionController>().user?.isAdmin ?? false;
    if (!canEdit) return;

    String currentRole = member.role;
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Alterar papel: ${member.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: currentRole,
                decoration: const InputDecoration(labelText: 'Papel de acesso'),
                items: const [
                  DropdownMenuItem(value: 'viewer', child: Text('Visualizador')),
                  DropdownMenuItem(value: 'operator', child: Text('Operador')),
                  DropdownMenuItem(value: 'manager', child: Text('Gerente')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => currentRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await context.read<AccountRepository>().updateMemberRole(member.id, currentRole);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AccountRepository>();
    final canInvite = context.watch<SessionController>().user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipe & Convites'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Membros'),
            Tab(text: 'Convites ativos'),
          ],
        ),
      ),
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              onPressed: _openInviteDialog,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Convidar'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          KeyedSubtree(
            key: ValueKey('members-$_revision'),
            child: AsyncView<List<OrgMember>>(
              load: repository.members,
              builder: (context, members) {
                if (members.isEmpty) return const EmptyState(message: 'Nenhum membro encontrado.');
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final color = roleColor(member.role);
                    final details = [
                      member.email,
                      member.positionLabel,
                      member.department,
                      member.phone,
                    ].where((s) => s != null && s.trim().isNotEmpty).map((s) => s!).join('\n');

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: UserAvatar(
                          name: member.displayName,
                          avatarUrl: member.avatarUrl,
                          radius: 22,
                          color: color,
                        ),
                        title: Text(
                          member.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(details),
                        isThreeLine: details.contains('\n'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusPill(label: roleLabel(member.role), color: color),
                            if (!member.active) ...[
                              const SizedBox(height: 4),
                              const StatusPill(label: 'Inativo', color: AppColors.textMuted),
                            ],
                          ],
                        ),
                        onTap: () => _changeMemberRole(member),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          KeyedSubtree(
            key: ValueKey('invites-$_revision'),
            child: AsyncView<List<OrgInvite>>(
              load: repository.invites,
              builder: (context, invites) {
                if (invites.isEmpty) {
                  return const EmptyState(
                    message: 'Nenhum convite pendente.',
                    icon: Icons.mail_outline,
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: invites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surface,
                          child: Icon(Icons.vpn_key_outlined, size: 20, color: AppColors.textPrimary),
                        ),
                        title: Text(
                          invite.email.isNotEmpty ? invite.email : 'Convite aberto (qualquer e-mail)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Código: ${invite.code}\nExpira em: ${formatDateTime(invite.expiresAt)}',
                        ),
                        trailing: StatusPill(
                          label: roleLabel(invite.role),
                          color: roleColor(invite.role),
                        ),
                        onTap: () => _showInviteCodeDialog(invite),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
