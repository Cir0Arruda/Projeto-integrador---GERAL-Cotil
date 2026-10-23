// ============================================================================
// ★ MODELOS DE ESTOQUE E MOVIMENTAÇÃO WMS (WMS_MODELS.DART) ★
// Estruturas de dados para materiais, movimentações e histórico:
// 1) MaterialItem: Código, descrição, quantidade em estoque, localização e foto :3
// 2) MovementItem: Entradas, saídas, transferências e motivos (✿◠‿◠)
// 3) ComponentItem: Kits de montagem e estruturas de peças BOM! (｡•̀ᴗ-)✧
// ============================================================================

import '../core/format.dart';

// Semáforo do nível de estoque da peça :3
enum StockLevel { healthy, low, empty }

// O material armazenado no estoque do galpão :3
class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.code,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.minQty,
    required this.unitPrice,
    required this.currency,
    this.maxQty = 0,
    this.warehouseId,
    this.brand,
    this.model,
    this.sector,
    this.location,
    this.barcode,
    this.imageUrl,
    this.imageData,
    this.interchangeable = false,
    this.interchangeWith,
    this.notes,
    this.machinery,
    this.machineryImage,
    this.machineryDesc,
    this.usageDesc,
    this.originCountry,
    this.manufacturerUrl,
    this.manualUrl,
    this.manualFilename,
    this.createdAt,
    this.updatedAt,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
    id: toInt(json['id']),
    code: toText(json['code']) ?? '',
    description: toText(json['description']) ?? '',
    unit: toText(json['unit']) ?? 'UN',
    quantity: toDouble(json['quantity']),
    minQty: toDouble(json['min_qty']),
    maxQty: toDouble(json['max_qty']),
    unitPrice: toDouble(json['unit_price']),
    currency: toText(json['currency']) ?? 'BRL',
    warehouseId: json['warehouse_id'] == null
        ? null
        : toInt(json['warehouse_id']),
    brand: toText(json['brand']),
    model: toText(json['model']),
    sector: toText(json['sector']),
    location: toText(json['location']),
    barcode: toText(json['barcode']),
    imageUrl: toText(json['image_url']),
    imageData: toText(json['image_data']),
    interchangeable:
        json['interchangeable'] == 1 || json['interchangeable'] == true,
    interchangeWith: toText(json['interchange_with']),
    notes: toText(json['notes']),
    machinery: toText(json['machinery']),
    machineryImage: toText(json['machinery_image']),
    machineryDesc: toText(json['machinery_desc']),
    usageDesc: toText(json['usage_desc']),
    originCountry: toText(json['origin_country']),
    manufacturerUrl: toText(json['manufacturer_url']),
    manualUrl: toText(json['manual_url']),
    manualFilename: toText(json['manual_filename']),
    createdAt: toDate(json['created_at']),
    updatedAt: toDate(json['updated_at']),
  );

  final int id;
  final String code;
  final String description;
  final String unit;
  final double quantity;
  final double minQty;
  final double maxQty;
  final double unitPrice;
  final String currency;
  final int? warehouseId;
  final String? brand;
  final String? model;
  final String? sector;
  final String? location;
  final String? barcode;
  final String? imageUrl;
  final String? imageData;
  final bool interchangeable;
  final String? interchangeWith;
  final String? notes;
  final String? machinery;
  final String? machineryImage;
  final String? machineryDesc;
  final String? usageDesc;
  final String? originCountry;
  final String? manufacturerUrl;
  final String? manualUrl;
  final String? manualFilename;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get totalValue => quantity * unitPrice;

  StockLevel get level {
    if (quantity <= 0) return StockLevel.empty;
    if (minQty > 0 && quantity <= minQty) return StockLevel.low;
    return StockLevel.healthy;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'material': '$code — $description',
    'location': location,
    'quantity': quantity,
    'color': '#3b82f6',
  };
}

class MovementRecord {
  const MovementRecord({
    required this.id,
    required this.isEntry,
    required this.quantity,
    required this.materialCode,
    required this.materialDescription,
    this.materialId,
    this.responsible,
    this.nfNumber,
    this.reason,
    this.notes,
    this.createdAt,
  });

  factory MovementRecord.fromJson(Map<String, dynamic> json) => MovementRecord(
    id: toInt(json['id']),
    isEntry: json['type'] == 'entrada',
    quantity: toDouble(json['quantity']),
    materialCode: toText(json['material_code']) ?? toText(json['code']) ?? '',
    materialDescription:
        toText(json['material_desc']) ?? toText(json['description']) ?? '',
    materialId: json['material_id'] == null ? null : toInt(json['material_id']),
    responsible: toText(json['responsible']),
    nfNumber: toText(json['nf_number']),
    reason: toText(json['reason']),
    notes: toText(json['notes']),
    createdAt: toDate(json['created_at']),
  );

  final int id;
  final bool isEntry;
  final double quantity;
  final String materialCode;
  final String materialDescription;
  final int? materialId;
  final String? responsible;
  final String? nfNumber;
  final String? reason;
  final String? notes;
  final DateTime? createdAt;
}

class MovementResult {
  const MovementResult({required this.newStock, required this.quantity});

  factory MovementResult.fromJson(Map<String, dynamic> json) => MovementResult(
    newStock: toDouble(json['new_stock']),
    quantity: toDouble(json['quantity']),
  );

  final double newStock;
  final double quantity;
}

class ComponentPart {
  const ComponentPart({required this.code, required this.quantity});

  factory ComponentPart.fromJson(Map<String, dynamic> json) => ComponentPart(
    code: toText(json['code']) ?? '',
    quantity: toDouble(json['qty']),
  );

  final String code;
  final double quantity;
}

class ComponentItem {
  const ComponentItem({
    required this.id,
    required this.name,
    this.description,
    this.parts = const [],
  });

  factory ComponentItem.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'];
    final parts = rawParts is List
        ? rawParts
              .whereType<Map<String, dynamic>>()
              .map(ComponentPart.fromJson)
              .toList()
        : const <ComponentPart>[];
    return ComponentItem(
      id: toInt(json['id']),
      name: toText(json['name']) ?? 'Componente',
      description: toText(json['description']),
      parts: parts,
    );
  }

  final int id;
  final String name;
  final String? description;
  final List<ComponentPart> parts;
}

class MaterialFile {
  const MaterialFile({
    required this.id,
    required this.filename,
    required this.fileType,
    required this.fileSize,
    this.category,
    this.description,
    this.url,
    this.createdAt,
  });

  factory MaterialFile.fromJson(Map<String, dynamic> json) => MaterialFile(
    id: toInt(json['id']),
    filename: toText(json['filename']) ?? 'arquivo',
    fileType:
        toText(json['mime_type']) ??
        toText(json['file_type']) ??
        'application/octet-stream',
    fileSize: toInt(json['file_size_kb']) > 0
        ? toInt(json['file_size_kb']) * 1024
        : toInt(json['file_size']),
    category: toText(json['category']),
    description: toText(json['description']),
    url: toText(json['file_url']) ?? toText(json['url']),
    createdAt: toDate(json['created_at']),
  );

  final int id;
  final String filename;
  final String fileType;
  final int fileSize;
  final String? category;
  final String? description;
  final String? url;
  final DateTime? createdAt;

  bool get is3D => [
    'stl',
    'obj',
    'gltf',
    'glb',
  ].contains(filename.split('.').last.toLowerCase());
}

class StockInsights {
  const StockInsights({
    this.totalMaterials = 0,
    this.totalQuantity = 0,
    this.stockValue = 0,
    this.criticalCount = 0,
    this.zeroCount = 0,
    this.criticalItems = const [],
  });

  factory StockInsights.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final rawCritical = json['critical_items'];
    final items = rawCritical is List
        ? rawCritical
              .whereType<Map<String, dynamic>>()
              .map(MaterialItem.fromJson)
              .toList()
        : const <MaterialItem>[];
    return StockInsights(
      totalMaterials: toInt(summary['materials']),
      totalQuantity: toDouble(summary['quantity']),
      stockValue: toDouble(summary['stock_value']),
      criticalCount: toInt(summary['critical']),
      zeroCount: toInt(summary['zero']),
      criticalItems: items,
    );
  }

  final int totalMaterials;
  final double totalQuantity;
  final double stockValue;
  final int criticalCount;
  final int zeroCount;
  final List<MaterialItem> criticalItems;
}
