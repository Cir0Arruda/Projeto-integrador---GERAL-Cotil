// ============================================================================
// ★ MODELOS DE ARMAZÉNS E PLANTAS BAIXAS (WAREHOUSE_MODELS.DART) ★
// Estruturas de dados para galpões, docas, prateleiras e mapas 2D/3D:
// 1) WarehouseTab: Nome do armazém, filial, layout_id e foto de capa :3
// 2) Blueprint & FloorPlan: Planta baixa com paredes, corredores e prateleiras (✿◠‿◠)
// 3) PlanItem: Coordenadas X, Y, ângulo e níveis de cada estante! (｡•̀ᴗ-)✧
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../core/format.dart';

// Representa a aba de um armazém disponível para seleção :3
class WarehouseTab {
  const WarehouseTab({
    required this.id,
    required this.name,
    this.layoutId,
    this.mapName,
    this.branchName,
    this.coverImage,
    this.tabNumber,
  });

  factory WarehouseTab.fromJson(Map<String, dynamic> json) => WarehouseTab(
        id: toInt(json['id']),
        name: toText(json['name']) ?? 'Armazém',
        layoutId: json['layout_id'] == null ? null : toInt(json['layout_id']),
        mapName: toText(json['map_name']),
        branchName: toText(json['branch_name']),
        coverImage: toText(json['cover_image']),
        tabNumber: json['tab_number'] == null ? null : toInt(json['tab_number']),
      );

  final int id;
  final String name;
  final int? layoutId;
  final String? mapName;
  final String? branchName;
  final String? coverImage;
  final int? tabNumber;
}

class PlanItem {
  const PlanItem({
    required this.id,
    required this.label,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
    this.x1 = 0,
    this.y1 = 0,
    this.x2 = 0,
    this.y2 = 0,
    this.angle = 0,
    this.color,
    this.levels = 0,
    this.positions = 0,
    this.warehouseId,
    this.visible = true,
    this.height3d = 0,
    this.shelfHeight = 0,
    this.wallHeight = 0,
    this.wallThickness = 0,
    this.elevation = 0,
    this.machineType,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        id: toText(json['id']) ?? '',
        label: toText(json['label']) ?? toText(json['id']) ?? '',
        x: toDouble(json['x']),
        y: toDouble(json['y']),
        w: toDouble(json['w']),
        h: toDouble(json['h']),
        x1: toDouble(json['x1']),
        y1: toDouble(json['y1']),
        x2: toDouble(json['x2']),
        y2: toDouble(json['y2']),
        angle: toDouble(json['angle']),
        color: toText(json['color']),
        levels: toInt(json['levels']),
        positions: toInt(json['positions']),
        warehouseId: json['warehouse_id'] == null ? null : toInt(json['warehouse_id']),
        visible: json['visible'] != false,
        height3d: toDouble(json['height3d'] ?? json['wallHeight'] ?? json['shelfHeight']),
        shelfHeight: toDouble(json['shelfHeight']),
        wallHeight: toDouble(json['wallHeight']),
        wallThickness: toDouble(json['wallThickness']),
        elevation: toDouble(json['elevation']),
        machineType: toText(json['machineType']),
      );

  final String id;
  final String label;
  final double x;
  final double y;
  final double w;
  final double h;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double angle;
  final String? color;
  final int levels;
  final int positions;
  final int? warehouseId;
  final bool visible;
  final double height3d;
  final double shelfHeight;
  final double wallHeight;
  final double wallThickness;
  final double elevation;
  final String? machineType;

  Offset get center => Offset(x + w / 2, y + h / 2);

  Rect get zoneRect => Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));

  bool contains(Offset point) {
    final local = point - center;
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);
    final dx = local.dx * cosA - local.dy * sinA;
    final dy = local.dx * sinA + local.dy * cosA;
    return dx.abs() <= w / 2 && dy.abs() <= h / 2;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'angle': angle,
        'color': color,
        'levels': levels,
        'positions': positions,
        'visible': visible,
        'height3d': height3d,
        'shelfHeight': shelfHeight,
        'wallHeight': wallHeight,
        'wallThickness': wallThickness,
        'elevation': elevation,
        if (machineType != null) 'machineType': machineType,
      };
}

class FloorPlan {
  const FloorPlan({
    this.walls = const [],
    this.paths = const [],
    this.stairs = const [],
    this.doors = const [],
    this.windows = const [],
    this.pillars = const [],
    this.zones = const [],
    this.shelves = const [],
    this.machines = const [],
    this.forklifts = const [],
    this.docks = const [],
  });

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    List<PlanItem> read(String key) => (json[key] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlanItem.fromJson)
        .where((item) => item.visible)
        .toList();
    return FloorPlan(
      walls: read('walls'),
      paths: read('paths'),
      stairs: read('stairs'),
      doors: read('doors'),
      windows: read('windows'),
      pillars: read('pillars'),
      zones: read('zones'),
      shelves: read('shelves'),
      machines: read('machines'),
      forklifts: read('forklifts'),
      docks: read('docks'),
    );
  }

  final List<PlanItem> walls;
  final List<PlanItem> paths;
  final List<PlanItem> stairs;
  final List<PlanItem> doors;
  final List<PlanItem> windows;
  final List<PlanItem> pillars;
  final List<PlanItem> zones;
  final List<PlanItem> shelves;
  final List<PlanItem> machines;
  final List<PlanItem> forklifts;
  final List<PlanItem> docks;

  bool get isEmpty =>
      walls.isEmpty &&
      paths.isEmpty &&
      stairs.isEmpty &&
      doors.isEmpty &&
      windows.isEmpty &&
      pillars.isEmpty &&
      zones.isEmpty &&
      shelves.isEmpty &&
      machines.isEmpty &&
      forklifts.isEmpty &&
      docks.isEmpty;

  Rect get bounds {
    Rect? result;
    void include(Rect rect) => result = result == null ? rect : result!.expandToInclude(rect);
    for (final item in [...walls, ...paths, ...stairs]) {
      include(Rect.fromPoints(Offset(item.x1, item.y1), Offset(item.x2, item.y2)));
    }
    for (final item in zones) {
      include(item.zoneRect);
    }
    for (final item in [...shelves, ...machines, ...forklifts, ...docks]) {
      include(Rect.fromLTWH(item.x, item.y, item.w, item.h));
    }
    for (final item in [...doors, ...windows, ...pillars]) {
      include(Rect.fromCenter(center: Offset(item.x, item.y), width: 40, height: 40));
    }
    return result ?? const Rect.fromLTWH(0, 0, 720, 480);
  }

  Map<String, dynamic> toJson() => {
        'walls': walls.map((i) => i.toJson()).toList(),
        'paths': paths.map((i) => i.toJson()).toList(),
        'stairs': stairs.map((i) => i.toJson()).toList(),
        'doors': doors.map((i) => i.toJson()).toList(),
        'windows': windows.map((i) => i.toJson()).toList(),
        'pillars': pillars.map((i) => i.toJson()).toList(),
        'zones': zones.map((i) => i.toJson()).toList(),
        'shelves': shelves.map((i) => i.toJson()).toList(),
        'machines': machines.map((i) => i.toJson()).toList(),
        'forklifts': forklifts.map((i) => i.toJson()).toList(),
        'docks': docks.map((i) => i.toJson()).toList(),
      };
}

class Blueprint {
  const Blueprint({
    required this.name,
    required this.floors,
    this.raw = const {},
    this.roomW = 720,
    this.roomH = 480,
    this.doorX = 620,
    this.doorY = 480,
    this.doorW = 100,
  });

  factory Blueprint.fromJson(Map<String, dynamic> layout) {
    dynamic data = layout['blueprint_data'];
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }
    final floors = <int, FloorPlan>{};
    if (data is Map<String, dynamic> && data['floors'] is Map) {
      (data['floors'] as Map).forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index != null && value is Map<String, dynamic>) {
          floors[index] = FloorPlan.fromJson(value);
        }
      });
    }
    final rawMap = data is Map<String, dynamic> ? data : layout;
    return Blueprint(
      name: toText(data is Map ? data['name'] : null) ?? toText(layout['name']) ?? '',
      floors: floors,
      raw: rawMap,
      roomW: toDouble(layout['room_w'] ?? 720),
      roomH: toDouble(layout['room_h'] ?? 480),
      doorX: toDouble(layout['door_x'] ?? 620),
      doorY: toDouble(layout['door_y'] ?? 480),
      doorW: toDouble(layout['door_w'] ?? 100),
    );
  }

  final String name;
  final Map<int, FloorPlan> floors;
  final Map<String, dynamic> raw;
  final double roomW;
  final double roomH;
  final double doorX;
  final double doorY;
  final double doorW;

  Map<String, dynamic> get rawData {
    if (raw.isNotEmpty && raw['floors'] != null) return raw;
    return {
      'name': name,
      'floors': floors.map((k, v) => MapEntry('$k', v.toJson())),
    };
  }

  List<int> get populatedFloors {
    final keys = floors.entries.where((e) => !e.value.isEmpty).map((e) => e.key).toList()..sort();
    return keys;
  }
}
