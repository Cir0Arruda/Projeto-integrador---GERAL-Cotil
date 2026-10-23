// ============================================================================
// ★ MÓVEIS E OBJETOS DO ESPAÇO (PERSONAL_OBJECTS_VIEW.DART) ★
// Lista todos os móveis, prateleiras, gaveteiros e mesas:
// 1) Dimensões físicas e capacidade de armazenamento :3
// 2) Quantos pertences estão guardados em cada compartimento (✿◠‿◠)
// 3) Edição rápida de nomes e características dos móveis! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';
import '../../widgets/dialogs.dart';
import 'personal_dialogs.dart';

// Telinha de catálogo dos seus móveis e compartimentos :3
class PersonalObjectsView extends StatefulWidget {
  const PersonalObjectsView({
    super.key,
    required this.spaces,
    required this.onNavigateToSpace,
    required this.onReload,
  });

  final List<PersonalSpace> spaces;
  final void Function(int spaceId, String objectId) onNavigateToSpace;
  final VoidCallback onReload;

  @override
  State<PersonalObjectsView> createState() => _PersonalObjectsViewState();
}

class _PersonalObjectsViewState extends State<PersonalObjectsView> {
  final _search = TextEditingController();
  int? _selectedSpaceId;
  String _selectedCategory = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCompartments(
    PersonalSpace space,
    PersonalObject obj,
  ) async {
    final result = await showDialog<List<PersonalCompartment>>(
      context: context,
      builder: (_) => CompartmentsDialog(
        objectName: obj.name,
        compartments: obj.compartments,
      ),
    );
    if (result == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final idx = space.objects.indexWhere((o) => o.id == obj.id);
    if (idx >= 0) {
      space.objects[idx] = PersonalObject(
        id: obj.id,
        modelId: obj.modelId,
        name: obj.name,
        width: obj.width,
        depth: obj.depth,
        height: obj.height,
        x: obj.x,
        z: obj.z,
        yaw: obj.yaw,
        color: obj.color,
        quantity: obj.quantity,
        photo: obj.photo,
        hasPhoto: obj.hasPhoto,
        compartments: result,
      );
      try {
        await repo.updateSpace(space.id, space.toJson());
        if (mounted) {
          showToast(context, 'Locais atualizados.');
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

  Future<void> _addBelonging(PersonalSpace space, PersonalObject obj) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BelongingFormDialog(
        spaces: widget.spaces,
        initialSpaceId: space.id,
        initialObjectId: obj.id,
      ),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final item = PersonalBelonging(
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

    space.belongings.add(item);
    try {
      await repo.updateSpace(space.id, space.toJson());
      if (mounted) {
        showToast(context, 'Pertence "${item.name}" guardado.');
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

    final allItems =
        <({PersonalSpace space, PersonalObject object, CatalogModel? model})>[];
    for (final s in activeSpaces) {
      if (_selectedSpaceId != null && s.id != _selectedSpaceId) continue;
      for (final obj in s.objects) {
        final model = PersonalCatalog.findModel(obj.modelId);
        if (_selectedCategory.isNotEmpty &&
            model?.category != _selectedCategory) {
          continue;
        }
        if (query.isNotEmpty && !obj.name.toLowerCase().contains(query)) {
          continue;
        }
        allItems.add((space: s, object: obj, model: model));
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar seus móveis e objetos...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
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
                      initialValue: _selectedCategory,
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
                          value: '',
                          child: Text('Todas as categorias'),
                        ),
                        ...PersonalCatalog.categories.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: allItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum objeto encontrado neste filtro.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: allItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final obj = item.object;
                    final space = item.space;
                    final model = item.model;

                    final belongingsCount = space.belongings
                        .where((b) => b.objectId == obj.id)
                        .length;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _parseHex(obj.color),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.weekend_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        obj.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${space.name} · ${model?.category ?? 'Geral'}',
                                        style: const TextStyle(
                                          color: AppColors.brandText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${obj.quantity} unidade(s) · ${obj.width} × ${obj.depth} × ${obj.height} m · $belongingsCount pertence(s)',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => widget.onNavigateToSpace(
                                    space.id,
                                    obj.id,
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Ver no espaço'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openCompartments(space, obj),
                                  icon: const Icon(
                                    Icons.view_agenda_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Locais (${obj.compartments.length})',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _addBelonging(space, obj),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Guardar aqui'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
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
}

Color _parseHex(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFFC9B7A2);
  }
}
