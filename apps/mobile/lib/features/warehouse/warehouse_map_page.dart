// ============================================================================
// ★ MAPA DO ARMAZÉM EM 2D E 3D (WAREHOUSE_MAP_PAGE.DART) ★
// A funcionalidade visual mais impressionante do sistema! (✿◠‿◠)
// 1) Busca a planta baixa na API: GET /api/warehouses/:id/blueprint :3
// 2) Busca todos os materiais alocados: GET /api/materials (｡•̀ᴗ-)✧
// 3) Permite alternar entre visão 2D (planta interativa) e 3D realista (Three.js)! ヽ(>∀<☆)ノ
// 4) Destaca prateleiras e nichos onde cada peça está guardada! (o^▽^o)
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/warehouse_models.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../state/warehouse_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/warehouse_selector.dart';
import '../shared/labels.dart';
import 'view_3d_platform.dart';

typedef _MapData = ({Blueprint plan, List<MaterialItem> items});

enum _MapViewMode { mode2d, mode3d }

final RegExp _slotPattern = RegExp(r'^(.*)-N(\d+)-P(\d+)$');

const Color _colSteel = Color(0xFF667B8E);
const Color _colBlue = Color(0xFF487C91);
const Color _colYellow = Color(0xFFEAB308);
const Color _colWallTop = Color(0xFF64748B);

// Telinha interativa com mapa visual das prateleiras do galpão :3
class WarehouseMapPage extends StatefulWidget {
  const WarehouseMapPage({super.key, this.initialWarehouseId, this.highlightLocation});

  final int? initialWarehouseId;
  final String? highlightLocation;

  @override
  State<WarehouseMapPage> createState() => _WarehouseMapPageState();
}

class _WarehouseMapPageState extends State<WarehouseMapPage> {
  @override
  void initState() {
    super.initState();
    final id = widget.initialWarehouseId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final ctrl = context.read<WarehouseController>();
          if (ctrl.selectedId != id) ctrl.selectById(id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouseId = context.watch<WarehouseController>().selectedId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa do armazém'),
        actions: const [WarehouseSelector()],
      ),
      body: warehouseId == null
          ? const EmptyState(message: 'Nenhum armazém selecionado.', icon: Icons.map_outlined)
          : _MapLoader(
              key: ValueKey(warehouseId),
              warehouseId: warehouseId,
              highlightLocation: widget.highlightLocation,
            ),
    );
  }
}

class _MapLoader extends StatelessWidget {
  const _MapLoader({super.key, required this.warehouseId, this.highlightLocation});

  final int warehouseId;
  final String? highlightLocation;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<WmsRepository>();
    return AsyncView<_MapData>(
      load: () async {
        final results = await Future.wait<Object>([
          repository.blueprint(warehouseId),
          repository.materials(warehouseId: warehouseId),
        ]);
        return (plan: results[0] as Blueprint, items: results[1] as List<MaterialItem>);
      },
      builder: (context, data) {
        final floors = data.plan.populatedFloors;
        if (floors.isEmpty) {
          return const EmptyState(
            message: 'A planta deste armazém ainda não foi desenhada.',
            icon: Icons.map_outlined,
          );
        }
        return _PlanView(
          plan: data.plan,
          floors: floors,
          items: data.items,
          warehouseId: warehouseId,
          highlightLocation: highlightLocation,
        );
      },
    );
  }
}

class _PlanView extends StatefulWidget {
  const _PlanView({
    required this.plan,
    required this.floors,
    required this.items,
    required this.warehouseId,
    this.highlightLocation,
  });

  final Blueprint plan;
  final List<int> floors;
  final List<MaterialItem> items;
  final int warehouseId;
  final String? highlightLocation;

  @override
  State<_PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<_PlanView> {
  static const double _padding = 40;

  _MapViewMode _mode = _MapViewMode.mode3d;
  late int _floor = widget.floors.first;
  String? _selectedShelf;

  @override
  void initState() {
    super.initState();
    final loc = widget.highlightLocation;
    if (loc != null && loc.isNotEmpty) {
      final match = _slotPattern.firstMatch(loc);
      _selectedShelf = match != null ? match.group(1) : loc;
    }
  }

  FloorPlan get _current => widget.plan.floors[_floor] ?? const FloorPlan();

  Map<String, List<MaterialItem>> get _itemsByShelf {
    final result = <String, List<MaterialItem>>{};
    for (final item in widget.items) {
      final match = _slotPattern.firstMatch(item.location ?? '');
      if (match != null) result.putIfAbsent(match.group(1)!, () => []).add(item);
    }
    return result;
  }

  Future<void> _openShelf(PlanItem shelf, List<MaterialItem> items) async {
    setState(() => _selectedShelf = shelf.id);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShelfSheet(shelf: shelf, items: items),
    );
    if (mounted) setState(() => _selectedShelf = null);
  }

  @override
  Widget build(BuildContext context) {
    final floor = _current;
    final bounds = floor.bounds.inflate(_padding);
    final byShelf = _itemsByShelf;
    final occupied = byShelf.keys.toSet();
    final located = byShelf.values.fold<int>(0, (sum, list) => sum + list.length);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              SegmentedButton<_MapViewMode>(
                segments: const [
                  ButtonSegment<_MapViewMode>(
                    value: _MapViewMode.mode2d,
                    label: Text('2D'),
                    icon: Icon(Icons.layers_outlined, size: 18),
                  ),
                  ButtonSegment<_MapViewMode>(
                    value: _MapViewMode.mode3d,
                    label: Text('3D'),
                    icon: Icon(Icons.view_in_ar_outlined, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selected) {
                  setState(() => _mode = selected.first);
                },
              ),
              const Spacer(),
              if (widget.floors.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _floor,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: widget.floors.map((index) {
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(index == 0 ? 'Térreo' : 'Andar $index'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _floor = value);
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const _LegendDot(color: AppColors.brand, label: 'Com itens'),
              const SizedBox(width: 16),
              const _LegendDot(color: AppColors.textMuted, label: 'Vazia'),
              const Spacer(),
              Text(
                '${floor.shelves.length} prateleiras · $located itens',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _mode == _MapViewMode.mode2d
                  ? _build2DView(bounds, floor, byShelf, occupied)
                  : _build3DView(floor, byShelf),
            ),
          ),
        ),
      ],
    );
  }

  Widget _build2DView(
    Rect bounds,
    FloorPlan floor,
    Map<String, List<MaterialItem>> byShelf,
    Set<String> occupied,
  ) {
    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 6,
      boundaryMargin: const EdgeInsets.all(80),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: bounds.width,
            height: bounds.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final point = details.localPosition + bounds.topLeft;
                for (final shelf in floor.shelves.reversed) {
                  if (shelf.contains(point)) {
                    _openShelf(shelf, byShelf[shelf.id] ?? const []);
                    return;
                  }
                }
              },
              child: CustomPaint(
                painter: _PlanPainter(
                  floor: floor,
                  origin: bounds.topLeft,
                  occupied: occupied,
                  selectedShelf: _selectedShelf,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DView(FloorPlan floor, Map<String, List<MaterialItem>> byShelf) {
    final api = context.read<ApiClient>();
    final baseUrl = api.baseUrl;
    final itemsJson = widget.items.map((i) => i.toJson()).toList();
    return Warehouse3dEmbed(
      key: ValueKey('w3d-$_floor-${widget.warehouseId}'),
      baseUrl: baseUrl,
      blueprint: widget.plan.rawData,
      items: itemsJson,
      floor: _floor,
      warehouseName: widget.plan.name,
      onShelfSelected: (shelfId) {
        final shelf = floor.shelves.cast<PlanItem?>().firstWhere(
          (s) => s?.id == shelfId,
          orElse: () => null,
        );
        if (shelf != null) {
          _openShelf(shelf, byShelf[shelf.id] ?? const []);
        }
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ShelfSheet extends StatelessWidget {
  const _ShelfSheet({required this.shelf, required this.items});

  final PlanItem shelf;
  final List<MaterialItem> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => (a.location ?? '').compareTo(b.location ?? ''));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prateleira ${shelf.label}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${shelf.levels} níveis × ${shelf.positions} posições',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum material alocado nesta prateleira.'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    final match = _slotPattern.firstMatch(item.location ?? '');
                    final slot = match == null ? '' : 'Nível ${match.group(2)} · Posição ${match.group(3)}';
                    return ListTile(
                      title: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.code} · $slot'),
                      trailing: Text(
                        formatQuantity(item.quantity),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: stockLevelColor(item.level),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.floor,
    required this.origin,
    required this.occupied,
    required this.selectedShelf,
  });

  final FloorPlan floor;
  final Offset origin;
  final Set<String> occupied;
  final String? selectedShelf;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFC));
    canvas.translate(-origin.dx, -origin.dy);
    _grid(canvas, Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height));

    for (final zone in floor.zones) {
      final rect = zone.zoneRect;
      canvas.drawRect(rect, Paint()..color = AppColors.info.withValues(alpha: 0.08));
      canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.info.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (final path in floor.paths) {
      canvas.drawLine(
        Offset(path.x1, path.y1),
        Offset(path.x2, path.y2),
        Paint()
          ..color = _colYellow
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final stairs in floor.stairs) {
      canvas.drawLine(
        Offset(stairs.x1, stairs.y1),
        Offset(stairs.x2, stairs.y2),
        Paint()
          ..color = AppColors.info
          ..strokeWidth = 8,
      );
    }
    for (final wall in floor.walls) {
      canvas.drawLine(
        Offset(wall.x1, wall.y1),
        Offset(wall.x2, wall.y2),
        Paint()
          ..color = _colWallTop
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.square,
      );
    }
    for (final item in [...floor.machines, ...floor.forklifts, ...floor.docks]) {
      _box(
        canvas,
        item,
        fill: _color(item.color, _colBlue).withValues(alpha: 0.85),
        border: _color(item.color, _colSteel),
        textColor: Colors.white,
        fontSize: 13,
      );
    }
    for (final pillar in floor.pillars) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(pillar.x, pillar.y), width: 20, height: 20),
        Paint()..color = const Color(0xFF475569),
      );
    }
    for (final door in floor.doors) {
      canvas.drawCircle(Offset(door.x, door.y), 14, Paint()..color = AppColors.brand);
    }
    for (final window in floor.windows) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(window.x, window.y), width: 36, height: 8),
        Paint()..color = AppColors.info,
      );
    }
    for (final shelf in floor.shelves) {
      final filled = occupied.contains(shelf.id);
      final accent = filled ? AppColors.brand : AppColors.textMuted;
      _box(
        canvas,
        shelf,
        fill: filled ? AppColors.brand.withValues(alpha: 0.18) : Colors.white,
        border: accent,
        borderWidth: selectedShelf == shelf.id ? 5 : 3,
        textColor: AppColors.textPrimary,
        fontSize: math.max(11, math.min(18, shelf.h * 0.38)),
      );
    }
  }

  void _grid(Canvas canvas, Rect area) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    const step = 50.0;
    for (var x = (area.left / step).floor() * step; x <= area.right; x += step) {
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), paint);
    }
    for (var y = (area.top / step).floor() * step; y <= area.bottom; y += step) {
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
    }
  }

  void _box(
    Canvas canvas,
    PlanItem item, {
    required Color fill,
    required Color border,
    required Color textColor,
    required double fontSize,
    double borderWidth = 2,
  }) {
    canvas.save();
    canvas.translate(item.center.dx, item.center.dy);
    canvas.rotate(item.angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: item.w, height: item.h);
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rounded, Paint()..color = fill);
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: item.label,
        style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(10, item.w - 8));
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  Color _color(String? hex, Color fallback) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return value == null ? fallback : Color(value);
  }

  @override
  bool shouldRepaint(covariant _PlanPainter old) =>
      old.floor != floor || old.occupied != occupied || old.selectedShelf != selectedShelf;
}
