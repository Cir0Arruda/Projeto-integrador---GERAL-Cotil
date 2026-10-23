// ============================================================================
// ★ VISUALIZADOR 2D DE PLANTAS DE ESPAÇOS PESSOAIS (PERSONAL_SPACES_VIEW.DART) ★
// Planta baixa interativa dos seus cômodos, mesas e armários:
// 1) Desenha as paredes, móveis, gavetas e caixas organizadoras :3
// 2) Permite zoom e pan suaves pra navegar pelo quarto/sala (✿◠‿◠)
// 3) Toque em qualquer móvel para ver o que tem guardado dentro dele! (｡•̀ᴗ-)✧
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';
import '../../widgets/dialogs.dart';
import 'personal_dialogs.dart';

// Telinha interativa com a planta baixa do cômodo pessoal :3
class PersonalSpacesView extends StatefulWidget {
  const PersonalSpacesView({
    super.key,
    required this.spaces,
    required this.currentSpace,
    required this.onSelectSpace,
    required this.onReload,
    required this.initialSelectedObjectId,
  });

  final List<PersonalSpace> spaces;
  final PersonalSpace? currentSpace;
  final ValueChanged<int?> onSelectSpace;
  final VoidCallback onReload;
  final String? initialSelectedObjectId;

  @override
  State<PersonalSpacesView> createState() => _PersonalSpacesViewState();
}

class _PersonalSpacesViewState extends State<PersonalSpacesView> {
  String? _selectedObjectId;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedObjectId = widget.initialSelectedObjectId;
  }

  @override
  void didUpdateWidget(covariant PersonalSpacesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedObjectId != null &&
        widget.initialSelectedObjectId != _selectedObjectId) {
      setState(() => _selectedObjectId = widget.initialSelectedObjectId);
    }
  }

  PersonalObject? get _selectedObject {
    if (widget.currentSpace == null || _selectedObjectId == null) return null;
    return widget.currentSpace!.objects
        .where((o) => o.id == _selectedObjectId)
        .firstOrNull;
  }

  Future<void> _saveSpace() async {
    if (widget.currentSpace == null || _saving) return;
    setState(() => _saving = true);
    final repo = context.read<PersonalRepository>();
    try {
      await repo.updateSpace(
        widget.currentSpace!.id,
        widget.currentSpace!.toJson(),
      );
      if (mounted) {
        setState(() => _dirty = false);
        showToast(context, 'Espaço salvo com sucesso.');
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createSpace() async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const SpaceFormDialog(),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final template = res['template'] as String;
    final width = res['width'] as double;
    final depth = res['depth'] as double;
    final name = res['name'] as String;

    final objects = <Map<String, dynamic>>[];
    if (template != 'empty') {
      final defaultItems = _templateObjects(template, width, depth);
      objects.addAll(defaultItems);
    }

    try {
      final created = await repo.createSpace({
        'name': name,
        'width': width,
        'depth': depth,
        'objects': objects,
        'tasks': [],
        'belongings': [],
      });
      if (mounted) {
        showToast(context, 'Espaço "${created.name}" criado.');
        widget.onReload();
        widget.onSelectSpace(created.id);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  List<Map<String, dynamic>> _templateObjects(
    String template,
    double width,
    double depth,
  ) {
    final items = <Map<String, dynamic>>[];
    if (template == 'office') {
      items.add({
        'id': 'obj_${DateTime.now().millisecondsSinceEpoch}_1',
        'modelId': 'desk',
        'name': 'Escrivaninha',
        'width': 1.4,
        'depth': 0.7,
        'height': 0.75,
        'x': width * 0.4,
        'z': depth * 0.4,
        'yaw': 0.0,
        'color': '#c9b7a2',
        'quantity': 1,
        'compartments': [
          {'id': 'c1', 'name': 'Gaveta'},
          {'id': 'c2', 'name': 'Tampo'},
        ],
      });
      items.add({
        'id': 'obj_${DateTime.now().millisecondsSinceEpoch}_2',
        'modelId': 'chair',
        'name': 'Cadeira',
        'width': 0.5,
        'depth': 0.5,
        'height': 0.85,
        'x': width * 0.4,
        'z': depth * 0.4 + 0.6,
        'yaw': 0.0,
        'color': '#76988a',
        'quantity': 1,
        'compartments': [],
      });
      items.add({
        'id': 'obj_${DateTime.now().millisecondsSinceEpoch}_3',
        'modelId': 'bookcase',
        'name': 'Estante',
        'width': 1.0,
        'depth': 0.35,
        'height': 1.8,
        'x': width * 0.8,
        'z': depth * 0.3,
        'yaw': 90.0,
        'color': '#bda68b',
        'quantity': 1,
        'compartments': [
          {'id': 'c1', 'name': 'Prateleira 1'},
          {'id': 'c2', 'name': 'Prateleira 2'},
        ],
      });
    } else if (template == 'bedroom') {
      items.add({
        'id': 'obj_${DateTime.now().millisecondsSinceEpoch}_1',
        'modelId': 'bed',
        'name': 'Cama',
        'width': 1.6,
        'depth': 2.0,
        'height': 0.9,
        'x': width * 0.5,
        'z': depth * 0.5,
        'yaw': 0.0,
        'color': '#d7c6b7',
        'quantity': 1,
        'compartments': [],
      });
      items.add({
        'id': 'obj_${DateTime.now().millisecondsSinceEpoch}_2',
        'modelId': 'wardrobe',
        'name': 'Armário',
        'width': 1.4,
        'depth': 0.6,
        'height': 2.0,
        'x': width * 0.8,
        'z': depth * 0.3,
        'yaw': 90.0,
        'color': '#d9d0c2',
        'quantity': 1,
        'compartments': [
          {'id': 'c1', 'name': 'Cabideiro'},
          {'id': 'c2', 'name': 'Gavetas'},
        ],
      });
    } else {
      items.add({
        'id': 'obj_${DateTime.now().millisecondsSinceEpoch}_1',
        'modelId': 'sofa',
        'name': 'Sofá',
        'width': 2.0,
        'depth': 0.9,
        'height': 0.85,
        'x': width * 0.5,
        'z': depth * 0.5,
        'yaw': 0.0,
        'color': '#b1c4b8',
        'quantity': 1,
        'compartments': [],
      });
    }
    return items;
  }

  Future<void> _editSpaceSettings() async {
    if (widget.currentSpace == null) return;
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SpaceFormDialog(space: widget.currentSpace),
    );
    if (res == null || !mounted) return;

    final repo = context.read<PersonalRepository>();
    final space = widget.currentSpace!;
    final updated = PersonalSpace(
      id: space.id,
      name: res['name'] as String,
      width: res['width'] as double,
      depth: res['depth'] as double,
      objects: space.objects,
      tasks: space.tasks,
      belongings: space.belongings,
      history: space.history,
      version: space.version,
      archived: space.archived,
    );

    try {
      await repo.updateSpace(space.id, updated.toJson());
      if (mounted) {
        showToast(context, 'Medidas e nome atualizados.');
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  Future<void> _openLibrary() async {
    if (widget.currentSpace == null) return;
    final model = await showDialog<CatalogModel>(
      context: context,
      builder: (_) => const LibraryDialog(),
    );
    if (model == null || !mounted) return;

    final space = widget.currentSpace!;
    final newObj = PersonalObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
      modelId: model.id,
      name: model.name,
      width: model.width,
      depth: model.depth,
      height: model.height,
      x: space.width / 2,
      z: space.depth / 2,
      yaw: 0,
      color: model.color,
      quantity: 1,
      compartments: model.defaultPlaces
          .asMap()
          .entries
          .map((e) => PersonalCompartment(id: 'c_${e.key}', name: e.value))
          .toList(),
    );

    space.objects.add(newObj);
    setState(() {
      _selectedObjectId = newObj.id;
      _dirty = true;
    });
    await _saveSpace();
  }

  Future<void> _archiveSpace() async {
    if (widget.currentSpace == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar espaço?'),
        content: Text(
          'O espaço "${widget.currentSpace!.name}" será arquivado. Você poderá restaurá-lo em Resumo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final repo = context.read<PersonalRepository>();
    try {
      await repo.archiveSpace(
        widget.currentSpace!.id,
        widget.currentSpace!.version,
      );
      if (mounted) {
        showToast(context, 'Espaço arquivado.');
        widget.onReload();
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString(), error: e is! QueuedOperationException);
      }
    }
  }

  Future<void> _openCompartments() async {
    final obj = _selectedObject;
    if (obj == null || widget.currentSpace == null) return;

    final result = await showDialog<List<PersonalCompartment>>(
      context: context,
      builder: (_) => CompartmentsDialog(
        objectName: obj.name,
        compartments: obj.compartments,
      ),
    );
    if (result == null || !mounted) return;

    final idx = widget.currentSpace!.objects.indexWhere((o) => o.id == obj.id);
    if (idx >= 0) {
      final updated = PersonalObject(
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
      widget.currentSpace!.objects[idx] = updated;
      setState(() => _dirty = true);
      await _saveSpace();
    }
  }

  Future<void> _addBelongingHere() async {
    final obj = _selectedObject;
    if (widget.currentSpace == null) return;

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BelongingFormDialog(
        spaces: widget.spaces,
        initialSpaceId: widget.currentSpace!.id,
        initialObjectId: obj?.id,
      ),
    );
    if (res == null || !mounted) return;

    final space = widget.currentSpace!;
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
    setState(() => _dirty = true);
    await _saveSpace();
    if (mounted) showToast(context, 'Pertence "${item.name}" guardado.');
  }

  Future<void> _addTaskHere() async {
    final obj = _selectedObject;
    if (widget.currentSpace == null) return;

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TaskFormDialog(
        spaces: widget.spaces,
        initialSpaceId: widget.currentSpace!.id,
        initialObjectId: obj?.id,
      ),
    );
    if (res == null || !mounted) return;

    final space = widget.currentSpace!;
    final task = PersonalTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: res['title'] as String,
      due: res['due'] as String,
      spaceId: space.id,
      spaceName: space.name,
      objectId: res['objectId'] as String?,
      priority: res['priority'] as String? ?? 'normal',
      recurrence: res['recurrence'] as String? ?? 'none',
    );

    space.tasks.add(task);
    setState(() => _dirty = true);
    await _saveSpace();
    if (mounted) showToast(context, 'Tarefa agendada.');
  }

  void _removeSelectedObject() {
    final obj = _selectedObject;
    if (obj == null || widget.currentSpace == null) return;

    final hasBelongings = widget.currentSpace!.belongings.any(
      (b) => b.objectId == obj.id,
    );
    if (hasBelongings) {
      showToast(
        context,
        'Transfira os pertences deste móvel antes de removê-lo.',
        error: true,
      );
      return;
    }

    widget.currentSpace!.objects.removeWhere((o) => o.id == obj.id);
    setState(() {
      _selectedObjectId = null;
      _dirty = true;
    });
    _saveSpace();
  }

  @override
  Widget build(BuildContext context) {
    final activeSpaces = widget.spaces.where((s) => !s.archived).toList();

    if (activeSpaces.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.room_preferences_outlined,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Comece com um espaço seu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Monte um quarto, escritório ou qualquer cantinho que você queira organizar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _createSpace,
                icon: const Icon(Icons.add),
                label: const Text('Criar meu primeiro espaço'),
              ),
            ],
          ),
        ),
      );
    }

    final space = widget.currentSpace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<int>(
                  value: space?.id,
                  underline: const SizedBox.shrink(),
                  items: activeSpaces
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() => _selectedObjectId = null);
                    widget.onSelectSpace(id);
                  },
                ),
                const SizedBox(width: 8),
                if (space != null)
                  Text(
                    '${space.width} × ${space.depth} m · ${space.objects.length} objetos',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _openLibrary,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Objeto'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _editSpaceSettings,
                  icon: const Icon(Icons.straighten, size: 16),
                  label: const Text('Medidas'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _createSpace,
                  icon: const Icon(Icons.add_home_outlined, size: 16),
                  label: const Text('Novo Espaço'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _archiveSpace,
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Arquivar'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                if (_dirty)
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveSpace,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Salvar'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: space == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onTapUp: (details) {
                              final objId = _hitTest(
                                details.localPosition,
                                constraints.biggest,
                                space,
                              );
                              setState(() => _selectedObjectId = objId);
                            },
                            onPanUpdate: (details) {
                              if (_selectedObjectId == null) return;
                              final obj = _selectedObject;
                              if (obj == null) return;
                              final scale = _computeScale(
                                constraints.biggest,
                                space,
                              );

                              final dxMeters = details.delta.dx / scale;
                              final dzMeters = details.delta.dy / scale;

                              final newX = (obj.x + dxMeters).clamp(
                                0.0,
                                space.width,
                              );
                              final newZ = (obj.z + dzMeters).clamp(
                                0.0,
                                space.depth,
                              );

                              final idx = space.objects.indexWhere(
                                (o) => o.id == obj.id,
                              );
                              if (idx >= 0) {
                                space.objects[idx] = PersonalObject(
                                  id: obj.id,
                                  modelId: obj.modelId,
                                  name: obj.name,
                                  width: obj.width,
                                  depth: obj.depth,
                                  height: obj.height,
                                  x: newX,
                                  z: newZ,
                                  yaw: obj.yaw,
                                  color: obj.color,
                                  quantity: obj.quantity,
                                  photo: obj.photo,
                                  hasPhoto: obj.hasPhoto,
                                  compartments: obj.compartments,
                                );
                                setState(() => _dirty = true);
                              }
                            },
                            child: CustomPaint(
                              size: constraints.biggest,
                              painter: _RoomCanvasPainter(
                                space: space,
                                selectedObjectId: _selectedObjectId,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedObject != null)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: _buildObjectPanel(_selectedObject!),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildObjectPanel(PersonalObject obj) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _parseHex(obj.color),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.widgets_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obj.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${obj.width} × ${obj.depth} × ${obj.height} m · (${obj.x.toStringAsFixed(2)}, ${obj.z.toStringAsFixed(2)}) m',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedObjectId = null),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _openCompartments,
                    icon: const Icon(Icons.view_agenda_outlined, size: 16),
                    label: Text('Locais (${obj.compartments.length})'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addBelongingHere,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Guardar pertence'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addTaskHere,
                    icon: const Icon(Icons.task_alt, size: 16),
                    label: const Text('Agendar tarefa'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.rotate_right),
                    tooltip: 'Girar 45°',
                    onPressed: () {
                      final idx = widget.currentSpace!.objects.indexWhere(
                        (o) => o.id == obj.id,
                      );
                      if (idx >= 0) {
                        final newYaw = (obj.yaw + 45.0) % 360.0;
                        widget.currentSpace!.objects[idx] = PersonalObject(
                          id: obj.id,
                          modelId: obj.modelId,
                          name: obj.name,
                          width: obj.width,
                          depth: obj.depth,
                          height: obj.height,
                          x: obj.x,
                          z: obj.z,
                          yaw: newYaw,
                          color: obj.color,
                          quantity: obj.quantity,
                          photo: obj.photo,
                          hasPhoto: obj.hasPhoto,
                          compartments: obj.compartments,
                        );
                        setState(() => _dirty = true);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    tooltip: 'Remover objeto',
                    onPressed: _removeSelectedObject,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _computeScale(Size size, PersonalSpace space) {
    const pad = 40.0;
    final availW = size.width - pad * 2;
    final availH = size.height - pad * 2;
    final scaleW = availW / space.width;
    final scaleH = availH / space.depth;
    return math.min(scaleW, scaleH);
  }

  Offset _computeOffset(Size size, PersonalSpace space, double scale) {
    final roomPxW = space.width * scale;
    final roomPxH = space.depth * scale;
    final left = (size.width - roomPxW) / 2;
    final top = (size.height - roomPxH) / 2;
    return Offset(left, top);
  }

  String? _hitTest(Offset pos, Size size, PersonalSpace space) {
    final scale = _computeScale(size, space);
    final offset = _computeOffset(size, space, scale);

    final roomX = (pos.dx - offset.dx) / scale;
    final roomZ = (pos.dy - offset.dy) / scale;

    for (final obj in space.objects.reversed) {
      final left = obj.x - (obj.width / 2);
      final right = obj.x + (obj.width / 2);
      final top = obj.z - (obj.depth / 2);
      final bottom = obj.z + (obj.depth / 2);

      if (roomX >= left && roomX <= right && roomZ >= top && roomZ <= bottom) {
        return obj.id;
      }
    }
    return null;
  }
}

class _RoomCanvasPainter extends CustomPainter {
  const _RoomCanvasPainter({
    required this.space,
    required this.selectedObjectId,
  });

  final PersonalSpace space;
  final String? selectedObjectId;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 40.0;
    final availW = size.width - pad * 2;
    final availH = size.height - pad * 2;
    final scale = math.min(availW / space.width, availH / space.depth);

    final roomPxW = space.width * scale;
    final roomPxH = space.depth * scale;
    final left = (size.width - roomPxW) / 2;
    final top = (size.height - roomPxH) / 2;

    final roomRect = Rect.fromLTWH(left, top, roomPxW, roomPxH);

    final floorPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(roomRect, floorPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (double x = 1; x < space.width; x += 1) {
      final px = left + x * scale;
      canvas.drawLine(Offset(px, top), Offset(px, top + roomPxH), gridPaint);
    }
    for (double z = 1; z < space.depth; z += 1) {
      final py = top + z * scale;
      canvas.drawLine(Offset(left, py), Offset(left + roomPxW, py), gridPaint);
    }

    final wallPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(roomRect, wallPaint);

    for (final obj in space.objects) {
      final isSelected = obj.id == selectedObjectId;
      final objCenter = Offset(left + obj.x * scale, top + obj.z * scale);
      final objW = obj.width * scale;
      final objH = obj.depth * scale;

      canvas.save();
      canvas.translate(objCenter.dx, objCenter.dy);
      canvas.rotate(obj.yaw * math.pi / 180.0);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: objW,
        height: objH,
      );

      final fillPaint = Paint()
        ..color = _parseHex(obj.color)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        fillPaint,
      );

      final strokePaint = Paint()
        ..color = isSelected ? AppColors.brand : const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        strokePaint,
      );

      final textSpan = TextSpan(
        text: obj.name,
        style: TextStyle(
          color: Colors.black87,
          fontSize: (11.0).clamp(9.0, 14.0),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(objW + 20, 60));

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RoomCanvasPainter oldDelegate) => true;
}

Color _parseHex(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFFC9B7A2);
  }
}
