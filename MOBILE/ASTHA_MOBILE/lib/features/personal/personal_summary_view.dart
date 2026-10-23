// ============================================================================
// ★ RESUMO GERAL DOS ESPAÇOS PESSOAIS (PERSONAL_SUMMARY_VIEW.DART) ★
// Painel com visão panorâmica de todos os cômodos e armários da sua casa:
// 1) Contadores de espaços ativos, caixas e pertences guardados :3
// 2) Lista de espaços arquivados com botão de restauração rápida (✿◠‿◠)
// 3) Indicadores de ocupação e organização pessoal! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/dialogs.dart';

// Visão com estatísticas e resumo do seu inventário pessoal :3
class PersonalSummaryView extends StatelessWidget {
  const PersonalSummaryView({
    super.key,
    required this.spaces,
    required this.onReload,
  });

  final List<PersonalSpace> spaces;
  final VoidCallback onReload;

  Future<void> _restoreSpace(BuildContext context, PersonalSpace space) async {
    final repo = context.read<PersonalRepository>();
    try {
      await repo.restoreSpace(space.id, space.version);
      if (context.mounted) {
        showToast(context, 'Espaço "${space.name}" restaurado.');
        onReload();
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  Future<void> _switchToCorporate(BuildContext context) async {
    final session = context.read<SessionController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Usar uma conta corporativa'),
        content: const Text(
          'Seus dados pessoais permanecem nesta conta. Para acessar uma organização, saia e entre com a conta corporativa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sair e trocar de conta'),
          ),
        ],
      ),
    );
    if (confirmed == true) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final activeSpaces = spaces.where((s) => !s.archived).toList();
    final archivedSpaces = spaces.where((s) => s.archived).toList();

    final totalObjects = activeSpaces.fold(0, (n, s) => n + s.objects.length);
    final totalBelongings = activeSpaces.fold(
      0,
      (n, s) => n + s.belongings.length,
    );
    final allTasks = activeSpaces.expand((s) => s.tasks).toList();
    final pendingTasks = allTasks.where((t) => t.status == 'pending').length;
    final completedCount = allTasks.fold(
      0,
      (n, t) =>
          n +
          (t.completedOccurrences > 0
              ? t.completedOccurrences
              : (t.status == 'done' ? 1 : 0)),
    );

    final allHistory = activeSpaces
        .expand((s) => s.history.map((h) => (entry: h, spaceName: s.name)))
        .toList();
    allHistory.sort((a, b) => b.entry.at.compareTo(a.entry.at));
    final recentHistory = allHistory.take(25).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Espaços',
                  value: activeSpaces.length.toString(),
                  icon: Icons.room_preferences_outlined,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Móveis & Itens',
                  value: (totalObjects + totalBelongings).toString(),
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Tarefas Pendentes',
                  value: pendingTasks.toString(),
                  icon: Icons.schedule_outlined,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Conclusões',
                  value: completedCount.toString(),
                  icon: Icons.check_circle_outline,
                  color: AppColors.brandDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seu histórico recente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (recentHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Seu histórico aparecerá ao organizar seu primeiro espaço.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ...recentHistory.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontSize: 16,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_labelKind(h.entry.kind)} · ${h.entry.label}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${h.spaceName} · ${_formatTimestamp(h.entry.at)}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Espaços arquivados',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (archivedSpaces.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhum espaço arquivado.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ...archivedSpaces.map((s) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${s.objects.length} objetos · ${s.width} × ${s.depth} m',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _restoreSpace(context, s),
                          child: const Text('Restaurar'),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _switchToCorporate(context),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Entrar com uma conta corporativa'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelKind(String kind) {
    return switch (kind) {
      'space_created' => 'Espaço criado',
      'space_updated' => 'Espaço atualizado',
      'object_added' => 'Objeto adicionado',
      'object_updated' => 'Objeto atualizado',
      'object_removed' => 'Objeto removido',
      'task_added' => 'Tarefa criada',
      'task_updated' => 'Tarefa atualizada',
      'task_done' => 'Tarefa concluída',
      'task_removed' => 'Tarefa removida',
      'belonging_added' => 'Pertence cadastrado',
      'belonging_updated' => 'Pertence atualizado',
      'belonging_removed' => 'Pertence removido',
      _ => 'Alteração',
    };
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min';
    } catch (_) {
      return iso;
    }
  }
}
