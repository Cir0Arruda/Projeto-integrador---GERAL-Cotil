// ============================================================================
// ★ MENU MAIS OPÇÕES DO SISTEMA (MORE_PAGE.DART) ★
// A central de atalhos pra todas as outras funcionalidades do app! (✿◠‿◠)
// Dá acesso direto a:
// - Componentes & BOM :3
// - Mapa 2D/3D do galpão (｡•̀ᴗ-)✧
// - Relatórios de Movimentação (API GET /api/movements)
// - Estudos Analíticos e Insights
// - Gestão de Equipe e Colaboradores (GET /api/account/team)
// - Configurações do Servidor e Segurança! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/session_controller.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/user_avatar.dart';
import '../analytics/analytics_page.dart';
import '../components/components_page.dart';
import '../profile/profile_page.dart';
import '../reports/reports_page.dart';
import '../settings/corporate_settings_page.dart';
import '../settings/security_settings_page.dart';
import '../shared/labels.dart';
import '../team/team_page.dart';
import '../warehouse/warehouse_map_page.dart';

// Menu com cartõezinhos elegantes para navegar por todos os módulos :3
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user != null)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: UserAvatar(
                name: user.displayName,
                avatarUrl: user.avatarUrl,
                radius: 24,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${user.email}\n${roleLabel(user.role)}'),
              isThreeLine: true,
              onTap: () => _open(context, const ProfilePage()),
            ),
          ),
        const SizedBox(height: 12),
        _MenuTile(
          icon: Icons.account_tree_outlined,
          title: 'Componentes & BOM',
          subtitle: 'Estruturas e itens vinculados',
          onTap: () => _open(context, const ComponentsPage()),
        ),
        _MenuTile(
          icon: Icons.map_outlined,
          title: 'Mapa do armazém',
          subtitle: 'Layout e visualização 2D/3D',
          onTap: () => _open(context, const WarehouseMapPage()),
        ),
        _MenuTile(
          icon: Icons.bar_chart_outlined,
          title: 'Relatórios de movimentação',
          subtitle: 'Histórico de entradas e saídas',
          onTap: () => _open(context, const ReportsPage()),
        ),
        _MenuTile(
          icon: Icons.insights_outlined,
          title: 'Estúdio de análises',
          subtitle: 'Estudos e evidências reproduzíveis',
          onTap: () => _open(context, const AnalyticsPage()),
        ),
        _MenuTile(
          icon: Icons.room_preferences_outlined,
          title: 'Conta pessoal',
          subtitle: 'Acessar organização pessoal em uma conta separada',
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Usar uma conta pessoal'),
              content: const Text(
                'Esta conta pertence a uma organização corporativa. Para manter os dados da equipe protegidos, entre com uma conta pessoal para organizar sua casa e seus pertences.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Continuar nesta conta'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await session.signOut();
                  },
                  child: const Text('Sair e entrar com outra conta'),
                ),
              ],
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.business_outlined,
          title: 'Corporativo & Workspace',
          subtitle: 'Dados da empresa e filiais',
          onTap: () => _open(context, const CorporateSettingsPage()),
        ),
        _MenuTile(
          icon: Icons.groups_outlined,
          title: 'Equipe & Convites',
          subtitle: 'Gestão de membros e permissões',
          onTap: () => _open(context, const TeamPage()),
        ),
        _MenuTile(
          icon: Icons.security_outlined,
          title: 'Segurança & Senha',
          subtitle: 'Troca de senha e sessões ativas',
          onTap: () => _open(context, const SecuritySettingsPage()),
        ),
        _MenuTile(
          icon: Icons.person_outline,
          title: 'Meu perfil',
          subtitle: 'Dados pessoais e foto de perfil',
          onTap: () => _open(context, const ProfilePage()),
        ),
        _MenuTile(
          icon: Icons.wifi_tethering_rounded,
          title: 'Conexão & Multi-Redes',
          subtitle:
              '${session.serverUrl} · ${session.connectionService.isOnline ? "Online (${session.connectionService.latencyMs}ms) :3" : "Outra rede / Offline ;-;"}',
          onTap: () => showServerDialog(context),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: session.signOut,
          icon: const Icon(Icons.logout, color: AppColors.danger),
          label: const Text(
            'Sair do sistema',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.textMain, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: 18,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
