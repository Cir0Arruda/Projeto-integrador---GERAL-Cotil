// ============================================================================
// ★ AGENDA E LEMBRETES PESSOAIS (PERSONAL_AGENDA_VIEW.DART) ★
// Acompanhe tarefas, compromissos e devoluções de pertences:
// 1) Prazos de validade ou devolução de itens emprestados :3
// 2) Filtro por pendentes, concluídos ou atrasados (✿◠‿◠)
// 3) Marcação rápida de conclusão com feedback visual alegre! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';
import '../../widgets/dialogs.dart';
import 'personal_dialogs.dart';

// Telinha de agenda de compromissos e tarefas pessoais :3
class PersonalAgendaView extends StatefulWidget {
  const PersonalAgendaView({
    super.key,
    required this.spaces,
    required this.onReload,
  });

  final List<PersonalSpace> spaces;
  final VoidCallback onReload;

  @override
  State<PersonalAgendaView> createState() => _PersonalAgendaViewState();
}

class _PersonalAgendaViewState extends State<PersonalAgendaView> {
  String _filter = 'pending';

  Future<void> _createTask() async {
    final activeSpaces = widget.spaces.where((s) => !s.archived).toList();
    if (activeSpaces.isEmpty) {
      showToast(
        context,
        'Crie um espaço antes de agendar uma tarefa.',
        error: true,
      );
      return;
    }

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TaskFormDialog(spaces: widget.spaces),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final spaceId = res['spaceId'] as int;
    final space = widget.spaces.where((s) => s.id == spaceId).firstOrNull;
    if (space == null) return;

    final task = PersonalTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: res['title'] as String,
      due: res['due'] as String,
      spaceId: space.id,
      spaceName: space.name,
      objectId: res['objectId'] as String?,
      priority: res['priority'] as String? ?? 'normal',
      recurrence: res['recurrence'] as String? ?? 'none',
      status: 'pending',
    );

    space.tasks.add(task);
    try {
      await repo.updateSpace(space.id, space.toJson());
      if (mounted) {
        showToast(context, 'Tarefa "${task.title}" agendada.');
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  Future<void> _editTask(PersonalSpace space, PersonalTask task) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TaskFormDialog(spaces: widget.spaces, task: task),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final newSpaceId = res['spaceId'] as int;

    if (newSpaceId != space.id) {
      final targetSpace = widget.spaces
          .where((s) => s.id == newSpaceId)
          .firstOrNull;
      if (targetSpace != null) {
        space.tasks.removeWhere((t) => t.id == task.id);
        targetSpace.tasks.add(
          PersonalTask(
            id: task.id,
            title: res['title'] as String,
            due: res['due'] as String,
            spaceId: targetSpace.id,
            spaceName: targetSpace.name,
            objectId: res['objectId'] as String?,
            priority: res['priority'] as String? ?? 'normal',
            recurrence: res['recurrence'] as String? ?? 'none',
            status: task.status,
          ),
        );
        await repo.updateSpace(space.id, space.toJson());
        await repo.updateSpace(targetSpace.id, targetSpace.toJson());
      }
    } else {
      final idx = space.tasks.indexWhere((t) => t.id == task.id);
      if (idx >= 0) {
        space.tasks[idx] = PersonalTask(
          id: task.id,
          title: res['title'] as String,
          due: res['due'] as String,
          spaceId: space.id,
          spaceName: space.name,
          objectId: res['objectId'] as String?,
          priority: res['priority'] as String? ?? 'normal',
          recurrence: res['recurrence'] as String? ?? 'none',
          status: task.status,
        );
        await repo.updateSpace(space.id, space.toJson());
      }
    }

    if (mounted) {
      showToast(context, 'Tarefa atualizada.');
      widget.onReload();
    }
  }

  Future<void> _toggleTaskStatus(PersonalSpace space, PersonalTask task) async {
    final repo = context.read<PersonalRepository>();
    final idx = space.tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      final newStatus = task.status == 'done' ? 'pending' : 'done';
      space.tasks[idx] = PersonalTask(
        id: task.id,
        title: task.title,
        due: task.due,
        spaceId: space.id,
        spaceName: space.name,
        objectId: task.objectId,
        priority: task.priority,
        recurrence: task.recurrence,
        status: newStatus,
        lastCompletedAt: newStatus == 'done'
            ? DateTime.now().toIso8601String()
            : null,
        completedOccurrences: newStatus == 'done'
            ? task.completedOccurrences + 1
            : task.completedOccurrences,
      );

      try {
        await repo.updateSpace(space.id, space.toJson());
        if (mounted) {
          showToast(
            context,
            newStatus == 'done' ? 'Tarefa concluída!' : 'Tarefa reaberta.',
          );
          widget.onReload();
        }
      } catch (e) {
        if (mounted) {
          showToast(
            context,
            e.toString(),
            error: e is! QueuedOperationException,
          );
        }
      }
    }
  }

  Future<void> _deleteTask(PersonalSpace space, PersonalTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tarefa?'),
        content: Text('Deseja excluir "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final repo = context.read<PersonalRepository>();
    space.tasks.removeWhere((t) => t.id == task.id);
    try {
      await repo.updateSpace(space.id, space.toJson());
      if (mounted) {
        showToast(context, 'Tarefa excluída.');
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSpaces = widget.spaces.where((s) => !s.archived).toList();
    final nowIso = DateTime.now().toIso8601String().substring(0, 16);

    final allTasks = <({PersonalSpace space, PersonalTask task})>[];
    for (final s in activeSpaces) {
      for (final t in s.tasks) {
        final isPending = t.status == 'pending';
        final isOverdue = isPending && t.due.compareTo(nowIso) < 0;
        final isDone = t.status == 'done';

        if (_filter == 'pending' && !isPending) continue;
        if (_filter == 'overdue' && !isOverdue) continue;
        if (_filter == 'done' && !isDone) continue;

        allTasks.add((space: s, task: t));
      }
    }

    allTasks.sort((a, b) => a.task.due.compareTo(b.task.due));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Próximas e vencidas'),
                    ),
                    DropdownMenuItem(value: 'overdue', child: Text('Vencidas')),
                    DropdownMenuItem(value: 'done', child: Text('Concluídas')),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Todas as tarefas'),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _filter = val ?? 'pending'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _createTask,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova tarefa'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: allTasks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma tarefa neste filtro. Planeje seu próximo passo.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: allTasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pair = allTasks[index];
                    final space = pair.space;
                    final task = pair.task;

                    final object = space.objects
                        .where((o) => o.id == task.objectId)
                        .firstOrNull;
                    final isOverdue =
                        task.status == 'pending' &&
                        task.due.compareTo(nowIso) < 0;
                    final isDone = task.status == 'done';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isDone,
                              onChanged: (_) => _toggleTaskStatus(space, task),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: isDone
                                                ? AppColors.textMuted
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (isOverdue)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Vencida',
                                            style: TextStyle(
                                              color: Colors.red.shade800,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else if (isDone)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.brandLight,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Concluída',
                                            style: TextStyle(
                                              color: AppColors.brandDark,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${space.name}${object != null ? ' · ${object.name}' : ''}',
                                    style: const TextStyle(
                                      color: AppColors.brandText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDate(task.due)} · Prioridade ${_priorityLabel(task.priority)} · ${_recurrenceLabel(task.recurrence)}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') _editTask(space, task);
                                if (val == 'delete') _deleteTask(space, task);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Excluir',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
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

  String _priorityLabel(String p) {
    return switch (p) {
      'high' => 'Alta',
      'low' => 'Baixa',
      _ => 'Normal',
    };
  }

  String _recurrenceLabel(String r) {
    return switch (r) {
      'daily' => 'Diária',
      'weekly' => 'Semanal',
      'monthly' => 'Mensal',
      _ => 'Não repetir',
    };
  }
}
