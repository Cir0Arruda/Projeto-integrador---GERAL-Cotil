// ============================================================================
// ★ LISTA DE PERTENCES PESSOAIS (PERSONAL_BELONGINGS_VIEW.DART) ★
// Encontre qualquer coisa que você guardou em casa ou no escritório:
// 1) Busca rápida por nome, categoria ou etiqueta do pertence :3
// 2) Mostra exatamente em qual armário, gaveta ou prateleira o item tá (✿◠‿◠)
// 3) Permite mover pertences de um lugar para o outro num toque! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';
import '../../widgets/dialogs.dart';
import 'personal_dialogs.dart';

// Telinha para pesquisar e organizar todos os seus pertences guardados :3
class PersonalBelongingsView extends StatefulWidget {
  const PersonalBelongingsView({
    super.key,
    required this.spaces,
    required this.onNavigateToSpace,
    required this.onReload,
  });

  final List<PersonalSpace> spaces;
  final void Function(int spaceId, String objectId) onNavigateToSpace;
  final VoidCallback onReload;

  @override
  State<PersonalBelongingsView> createState() => _PersonalBelongingsViewState();
}

class _PersonalBelongingsViewState extends State<PersonalBelongingsView> {
  final _search = TextEditingController();
  int? _selectedSpaceId;
  String _selectedStatus = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFinder() async {
    final repo = context.read<PersonalRepository>();
    await showDialog(
      context: context,
      builder: (_) => PersonalFinderDialog(repo: repo),
    );
  }

  Future<void> _createBelonging() async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BelongingFormDialog(spaces: widget.spaces),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final spaceId = res['spaceId'] as int;
    final space = widget.spaces.where((s) => s.id == spaceId).firstOrNull;
    if (space == null) return;

    final newItem = PersonalBelonging(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      name: res['name'] as String,
      notes: res['notes'] as String?,
      tags: res['tags'] as String?,
      spaceId: space.id,
      spaceName: space.name,
      objectId: res['objectId'] as String?,
      compartmentId: res['compartmentId'] as String?,
      lastConfirmedAt: DateTime.now().toIso8601String(),
    );

    space.belongings.add(newItem);
    try {
      await repo.updateSpace(space.id, space.toJson());
      if (mounted) {
        showToast(context, 'Pertence "${newItem.name}" cadastrado.');
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  Future<void> _editBelonging(
    PersonalSpace space,
    PersonalBelonging item,
  ) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BelongingFormDialog(spaces: widget.spaces, item: item),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final newSpaceId = res['spaceId'] as int;

    if (newSpaceId != space.id) {
      final targetSpace = widget.spaces
          .where((s) => s.id == newSpaceId)
          .firstOrNull;
      if (targetSpace != null) {
        space.belongings.removeWhere((b) => b.id == item.id);
        targetSpace.belongings.add(
          PersonalBelonging(
            id: item.id,
            name: res['name'] as String,
            notes: res['notes'] as String?,
            tags: res['tags'] as String?,
            spaceId: targetSpace.id,
            spaceName: targetSpace.name,
            objectId: res['objectId'] as String?,
            compartmentId: res['compartmentId'] as String?,
            lastConfirmedAt: DateTime.now().toIso8601String(),
          ),
        );
        await repo.updateSpace(space.id, space.toJson());
        await repo.updateSpace(targetSpace.id, targetSpace.toJson());
      }
    } else {
      final idx = space.belongings.indexWhere((b) => b.id == item.id);
      if (idx >= 0) {
        space.belongings[idx] = PersonalBelonging(
          id: item.id,
          name: res['name'] as String,
          notes: res['notes'] as String?,
          tags: res['tags'] as String?,
          spaceId: space.id,
          spaceName: space.name,
          objectId: res['objectId'] as String?,
          compartmentId: res['compartmentId'] as String?,
          lastConfirmedAt: DateTime.now().toIso8601String(),
        );
        await repo.updateSpace(space.id, space.toJson());
      }
    }

    if (mounted) {
      showToast(context, 'Pertence atualizado.');
      widget.onReload();
    }
  }

  Future<void> _updateStatus(
    PersonalSpace space,
    PersonalBelonging item,
    String newStatus,
  ) async {
    final repo = context.read<PersonalRepository>();
    final idx = space.belongings.indexWhere((b) => b.id == item.id);
    if (idx >= 0) {
      space.belongings[idx] = PersonalBelonging(
        id: item.id,
        name: item.name,
        notes: item.notes,
        tags: item.tags,
        spaceId: space.id,
        spaceName: space.name,
        objectId: item.objectId,
        compartmentId: item.compartmentId,
        locationLabel: newStatus,
        lastConfirmedAt: DateTime.now().toIso8601String(),
      );
      try {
        await repo.updateSpace(space.id, space.toJson());
        if (mounted) {
          showToast(context, 'Situação do pertence atualizada.');
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

  Future<void> _deleteBelonging(
    PersonalSpace space,
    PersonalBelonging item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir pertence?'),
        content: Text(
          'Deseja excluir "${item.name}"? O registro será removido do espaço.',
        ),
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
    space.belongings.removeWhere((b) => b.id == item.id);
    try {
      await repo.updateSpace(space.id, space.toJson());
      if (mounted) {
        showToast(context, 'Pertence removido.');
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
    final query = _search.text.toLowerCase().trim();

    final allBelongings = <({PersonalSpace space, PersonalBelonging item})>[];
    for (final s in activeSpaces) {
      if (_selectedSpaceId != null && s.id != _selectedSpaceId) continue;
      for (final b in s.belongings) {
        final matchesQuery =
            query.isEmpty ||
            b.name.toLowerCase().contains(query) ||
            (b.notes?.toLowerCase().contains(query) ?? false) ||
            (b.tags?.toLowerCase().contains(query) ?? false);
        if (!matchesQuery) continue;
        allBelongings.add((space: s, item: b));
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Nome, característica ou local...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _openFinder,
                    icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                    label: const Text('IA'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createBelonging,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Cadastrar'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedSpaceId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos os espaços'),
                        ),
                        ...activeSpaces.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedSpaceId = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
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
                          value: '',
                          child: Text('Todas as situações'),
                        ),
                        DropdownMenuItem(
                          value: 'stored',
                          child: Text('Guardado'),
                        ),
                        DropdownMenuItem(
                          value: 'missing',
                          child: Text('Não encontrado'),
                        ),
                        DropdownMenuItem(
                          value: 'with-me',
                          child: Text('Comigo'),
                        ),
                        DropdownMenuItem(
                          value: 'borrowed',
                          child: Text('Emprestado'),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: allBelongings.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum pertence cadastrado neste filtro.\nCadastre um item e indique o móvel ou a gaveta onde ele fica.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: allBelongings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pair = allBelongings[index];
                    final space = pair.space;
                    final item = pair.item;

                    final object = space.objects
                        .where((o) => o.id == item.objectId)
                        .firstOrNull;
                    final comp = object?.compartments
                        .where((c) => c.id == item.compartmentId)
                        .firstOrNull;

                    final locationParts = [
                      space.name,
                      if (object != null) object.name,
                      if (comp != null) comp.name,
                    ];
                    final locationBreadcrumb = locationParts.join(' → ');

                    final isMissing = item.locationLabel == 'missing';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isMissing
                                      ? Colors.red.shade50
                                      : AppColors.brandLight,
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: isMissing
                                        ? Colors.red
                                        : AppColors.brand,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        locationBreadcrumb,
                                        style: const TextStyle(
                                          color: AppColors.brandText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMissing
                                        ? Colors.red.shade100
                                        : AppColors.brandLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isMissing ? 'Não encontrado' : 'Guardado',
                                    style: TextStyle(
                                      color: isMissing
                                          ? Colors.red.shade800
                                          : AppColors.brandDark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.notes != null &&
                                item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.notes!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            if (item.tags != null && item.tags!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tags: ${item.tags}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (object != null)
                                  OutlinedButton.icon(
                                    onPressed: () => widget.onNavigateToSpace(
                                      space.id,
                                      object.id,
                                    ),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Ver no 2D'),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _editBelonging(space, item),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Detalhes e local'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                if (!isMissing)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _updateStatus(space, item, 'missing'),
                                    icon: const Icon(
                                      Icons.search_off_outlined,
                                      size: 16,
                                      color: AppColors.danger,
                                    ),
                                    label: const Text(
                                      'Não encontro',
                                      style: TextStyle(color: AppColors.danger),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                else
                                  FilledButton.icon(
                                    onPressed: () =>
                                        _updateStatus(space, item, 'stored'),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Encontrei'),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      _deleteBelonging(space, item),
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
}
