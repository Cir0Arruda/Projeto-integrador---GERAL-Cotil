// ============================================================================
// ★ MODELOS DE ORGANIZAÇÃO PESSOAL (PERSONAL_MODELS.DART) ★
// Estruturas de dados para o módulo pessoal e residencial do usuário:
// 1) PersonalSpace: Cômodos, dimensões (largura/profundidade) e versão :3
// 2) PersonalObject: Móveis, armários, prateleiras e gavetas (✿◠‿◠)
// 3) PersonalBelonging: Pertences pessoais com fotos e localização exata! (｡•̀ᴗ-)✧
// ============================================================================

import '../core/format.dart';

// Representa um cômodo ou espaço pessoal organizado :3
class PersonalSpace {
  const PersonalSpace({
    required this.id,
    required this.name,
    required this.width,
    required this.depth,
    this.objects = const [],
    this.tasks = const [],
    this.belongings = const [],
    this.history = const [],
    this.version = 0,
    this.archived = false,
    this.updatedAt,
  });

  factory PersonalSpace.fromJson(Map<String, dynamic> json) {
    final rawObjects = json['objects'];
    final objects = rawObjects is List
        ? rawObjects.whereType<Map<String, dynamic>>().map(PersonalObject.fromJson).toList()
        : const <PersonalObject>[];

    final rawTasks = json['tasks'];
    final tasks = rawTasks is List
        ? rawTasks.whereType<Map<String, dynamic>>().map(PersonalTask.fromJson).toList()
        : const <PersonalTask>[];

    final rawBelongings = json['belongings'];
    final belongings = rawBelongings is List
        ? rawBelongings.whereType<Map<String, dynamic>>().map(PersonalBelonging.fromJson).toList()
        : const <PersonalBelonging>[];

    final rawHistory = json['history'];
    final history = rawHistory is List
        ? rawHistory.whereType<Map<String, dynamic>>().map(PersonalHistoryEntry.fromJson).toList()
        : const <PersonalHistoryEntry>[];

    return PersonalSpace(
      id: toInt(json['id']),
      name: toText(json['name']) ?? 'Espaço',
      width: toDouble(json['width']) > 0 ? toDouble(json['width']) : 6.0,
      depth: toDouble(json['depth']) > 0 ? toDouble(json['depth']) : 5.0,
      objects: objects,
      tasks: tasks,
      belongings: belongings,
      history: history,
      version: toInt(json['version']),
      archived: json['archived'] == true,
      updatedAt: toDate(json['updatedAt']),
    );
  }

  final int id;
  final String name;
  final double width;
  final double depth;
  final List<PersonalObject> objects;
  final List<PersonalTask> tasks;
  final List<PersonalBelonging> belongings;
  final List<PersonalHistoryEntry> history;
  final int version;
  final bool archived;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'width': width,
        'depth': depth,
        'version': version,
        'objects': objects.map((o) => o.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'belongings': belongings.map((b) => b.toJson()).toList(),
      };
}

class PersonalObject {
  const PersonalObject({
    required this.id,
    required this.modelId,
    required this.name,
    required this.width,
    required this.depth,
    required this.height,
    required this.x,
    required this.z,
    this.yaw = 0,
    this.color = '#c9b7a2',
    this.quantity = 1,
    this.photo,
    this.hasPhoto = false,
    this.compartments = const [],
  });

  factory PersonalObject.fromJson(Map<String, dynamic> json) {
    final rawComp = json['compartments'];
    final comp = rawComp is List
        ? rawComp.whereType<Map<String, dynamic>>().map(PersonalCompartment.fromJson).toList()
        : const <PersonalCompartment>[];

    return PersonalObject(
      id: toText(json['id']) ?? '',
      modelId: toText(json['modelId']) ?? 'desk',
      name: toText(json['name']) ?? 'Objeto',
      width: toDouble(json['width']),
      depth: toDouble(json['depth']),
      height: toDouble(json['height']),
      x: toDouble(json['x']),
      z: toDouble(json['z']),
      yaw: toDouble(json['yaw']),
      color: toText(json['color']) ?? '#c9b7a2',
      quantity: toInt(json['quantity']) > 0 ? toInt(json['quantity']) : 1,
      photo: toText(json['photo']),
      hasPhoto: json['hasPhoto'] == true || (toText(json['photo'])?.isNotEmpty ?? false),
      compartments: comp,
    );
  }

  final String id;
  final String modelId;
  final String name;
  final double width;
  final double depth;
  final double height;
  final double x;
  final double z;
  final double yaw;
  final String color;
  final int quantity;
  final String? photo;
  final bool hasPhoto;
  final List<PersonalCompartment> compartments;

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelId': modelId,
        'name': name,
        'width': width,
        'depth': depth,
        'height': height,
        'x': x,
        'z': z,
        'yaw': yaw,
        'color': color,
        'quantity': quantity,
        'photo': photo,
        'compartments': compartments.map((c) => c.toJson()).toList(),
      };
}

class PersonalCompartment {
  const PersonalCompartment({required this.id, required this.name});

  factory PersonalCompartment.fromJson(Map<String, dynamic> json) => PersonalCompartment(
        id: toText(json['id']) ?? '',
        name: toText(json['name']) ?? 'Compartimento',
      );

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class PersonalTask {
  const PersonalTask({
    required this.id,
    required this.title,
    required this.due,
    this.objectId,
    this.priority = 'normal',
    this.recurrence = 'none',
    this.status = 'pending',
    this.completedOccurrences = 0,
    this.lastCompletedAt,
    this.spaceId,
    this.spaceName,
    this.objectName,
  });

  factory PersonalTask.fromJson(Map<String, dynamic> json) => PersonalTask(
        id: toText(json['id']) ?? '',
        title: toText(json['title']) ?? '',
        due: toText(json['due']) ?? '',
        objectId: toText(json['objectId']),
        priority: toText(json['priority']) ?? 'normal',
        recurrence: toText(json['recurrence']) ?? 'none',
        status: toText(json['status']) ?? 'pending',
        completedOccurrences: toInt(json['completedOccurrences']),
        lastCompletedAt: toText(json['lastCompletedAt']),
        spaceId: json['spaceId'] != null ? toInt(json['spaceId']) : null,
        spaceName: toText(json['spaceName']),
        objectName: toText(json['objectName']),
      );

  final String id;
  final String title;
  final String due;
  final String? objectId;
  final String priority;
  final String recurrence;
  final String status;
  final int completedOccurrences;
  final String? lastCompletedAt;
  final int? spaceId;
  final String? spaceName;
  final String? objectName;

  bool get isDone => status == 'done';
  bool get isHighPriority => priority == 'high';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'due': due,
        'objectId': objectId,
        'priority': priority,
        'recurrence': recurrence,
        'status': status,
      };
}

class PersonalBelonging {
  const PersonalBelonging({
    required this.id,
    required this.name,
    this.objectId,
    this.compartmentId,
    this.notes,
    this.photo,
    this.hasPhoto = false,
    this.tags,
    this.locationLabel,
    this.lastConfirmedAt,
    this.spaceId,
    this.spaceName,
    this.score = 0,
  });

  factory PersonalBelonging.fromJson(Map<String, dynamic> json) => PersonalBelonging(
        id: toText(json['id']) ?? '',
        name: toText(json['name']) ?? 'Pertence',
        objectId: toText(json['objectId']),
        compartmentId: toText(json['compartmentId']),
        notes: toText(json['notes']),
        photo: toText(json['photo']),
        hasPhoto: json['hasPhoto'] == true || (toText(json['photo'])?.isNotEmpty ?? false),
        tags: toText(json['tags']),
        locationLabel: toText(json['location']),
        lastConfirmedAt: toText(json['lastConfirmedAt']),
        spaceId: json['spaceId'] != null ? toInt(json['spaceId']) : null,
        spaceName: toText(json['spaceName']),
        score: toInt(json['score']),
      );

  final String id;
  final String name;
  final String? objectId;
  final String? compartmentId;
  final String? notes;
  final String? photo;
  final bool hasPhoto;
  final String? tags;
  final String? locationLabel;
  final String? lastConfirmedAt;
  final int? spaceId;
  final String? spaceName;
  final int score;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'objectId': objectId,
        'compartmentId': compartmentId,
        'notes': notes,
        'photo': photo,
        'tags': tags,
      };
}

class PersonalHistoryEntry {
  const PersonalHistoryEntry({
    required this.id,
    required this.kind,
    required this.label,
    required this.at,
    this.space,
  });

  factory PersonalHistoryEntry.fromJson(Map<String, dynamic> json) => PersonalHistoryEntry(
        id: toText(json['id']) ?? '',
        kind: toText(json['kind']) ?? '',
        label: toText(json['label']) ?? '',
        at: toText(json['at']) ?? '',
        space: toText(json['space']),
      );

  final String id;
  final String kind;
  final String label;
  final String at;
  final String? space;
}

class PersonalFindAnswer {
  const PersonalFindAnswer({
    this.results = const [],
    this.notice = '',
    this.message = '',
  });

  factory PersonalFindAnswer.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(PersonalBelonging.fromJson).toList()
        : const <PersonalBelonging>[];
    return PersonalFindAnswer(
      results: items,
      notice: toText(json['notice']) ?? '',
      message: toText(json['message']) ?? '',
    );
  }

  final List<PersonalBelonging> results;
  final String notice;
  final String message;
}

class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.depth,
    required this.height,
    required this.color,
    this.defaultPlaces = const [],
  });

  final String id;
  final String name;
  final String category;
  final double width;
  final double depth;
  final double height;
  final String color;
  final List<String> defaultPlaces;
}

class PersonalCatalog {
  static const List<String> categories = [
    'Móveis',
    'Trabalho',
    'Organização',
    'Casa',
    'Decoração',
    'Lazer',
    'Eletrônicos',
    'Papelaria',
    'Livros',
    'Brinquedos',
    'Cozinha',
    'Quarto e sala',
    'Ferramentas',
    'Banheiro',
  ];

  static const List<CatalogModel> models = [
    CatalogModel(id: 'desk', name: 'Escrivaninha', category: 'Trabalho', width: 1.4, depth: 0.7, height: 0.75, color: '#c9b7a2', defaultPlaces: ['Gaveta', 'Tampo']),
    CatalogModel(id: 'table', name: 'Mesa', category: 'Móveis', width: 1.4, depth: 0.9, height: 0.75, color: '#c9b7a2', defaultPlaces: ['Tampo']),
    CatalogModel(id: 'chair', name: 'Cadeira', category: 'Móveis', width: 0.5, depth: 0.5, height: 0.85, color: '#76988a'),
    CatalogModel(id: 'sofa', name: 'Sofá', category: 'Móveis', width: 2.0, depth: 0.9, height: 0.85, color: '#b1c4b8'),
    CatalogModel(id: 'bed', name: 'Cama', category: 'Móveis', width: 1.6, depth: 2.0, height: 0.9, color: '#d7c6b7'),
    CatalogModel(id: 'wardrobe', name: 'Armário', category: 'Organização', width: 1.4, depth: 0.6, height: 2.0, color: '#d9d0c2', defaultPlaces: ['Prateleira superior', 'Cabideiro', 'Gaveta']),
    CatalogModel(id: 'drawer', name: 'Cômoda', category: 'Organização', width: 1.0, depth: 0.5, height: 0.85, color: '#c5af94', defaultPlaces: ['Gaveta superior', 'Gaveta do meio', 'Gaveta inferior']),
    CatalogModel(id: 'bookcase', name: 'Estante', category: 'Organização', width: 1.0, depth: 0.35, height: 1.8, color: '#bda68b', defaultPlaces: ['Prateleira 1', 'Prateleira 2', 'Prateleira 3']),
    CatalogModel(id: 'box', name: 'Caixa organizadora', category: 'Organização', width: 0.4, depth: 0.3, height: 0.3, color: '#a5b7b0', defaultPlaces: ['Interior']),
    CatalogModel(id: 'books', name: 'Livros', category: 'Objetos', width: 0.35, depth: 0.25, height: 0.25, color: '#7b9288'),
    CatalogModel(id: 'computer', name: 'Computador', category: 'Trabalho', width: 0.6, depth: 0.3, height: 0.5, color: '#526078'),
    CatalogModel(id: 'tv', name: 'Televisão', category: 'Objetos', width: 1.2, depth: 0.22, height: 0.75, color: '#526078'),
    CatalogModel(id: 'fridge', name: 'Geladeira', category: 'Casa', width: 0.75, depth: 0.7, height: 1.85, color: '#d6dcdd', defaultPlaces: ['Prateleira superior', 'Prateleira inferior', 'Porta']),
    CatalogModel(id: 'stove', name: 'Fogão', category: 'Casa', width: 0.6, depth: 0.6, height: 0.9, color: '#e2e3dd'),
    CatalogModel(id: 'microwave', name: 'Micro-ondas', category: 'Casa', width: 0.5, depth: 0.4, height: 0.3, color: '#d6dcdd'),
    CatalogModel(id: 'washer', name: 'Máquina de lavar', category: 'Casa', width: 0.6, depth: 0.6, height: 0.9, color: '#e8e9e4'),
    CatalogModel(id: 'plant', name: 'Planta', category: 'Decoração', width: 0.5, depth: 0.5, height: 1.0, color: '#739779'),
    CatalogModel(id: 'lamp', name: 'Luminária', category: 'Decoração', width: 0.4, depth: 0.4, height: 1.6, color: '#c8ad74'),
    CatalogModel(id: 'rug', name: 'Tapete', category: 'Decoração', width: 1.8, depth: 1.2, height: 0.03, color: '#d6bfb0'),
    CatalogModel(id: 'laptop', name: 'Notebook', category: 'Eletrônicos', width: 0.34, depth: 0.24, height: 0.23, color: '#677881'),
    CatalogModel(id: 'toolbox', name: 'Caixa de ferramentas', category: 'Ferramentas', width: 0.4, depth: 0.2, height: 0.2, color: '#ae9b84', defaultPlaces: ['Bandeja superior', 'Compartimento inferior']),
    CatalogModel(id: 'backpack', name: 'Mochila', category: 'Quarto e sala', width: 0.3, depth: 0.18, height: 0.42, color: '#7b9a94', defaultPlaces: ['Bolso principal', 'Bolso frontal']),
  ];

  static CatalogModel? findModel(String id) {
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }
}
