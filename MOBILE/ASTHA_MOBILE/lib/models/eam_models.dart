// ============================================================================
// ★ MODELOS DE ATIVOS E ORDENS DE MANUTENÇÃO (EAM_MODELS.DART) ★
// Estruturas de dados para maquinário, manutenções e confiabilidade:
// 1) AssetItem: Máquinas, empilhadeiras, número de série e horímetro :3
// 2) WorkOrder: Chamados de conserto e preventivas da equipe técnica (✿◠‿◠)
// 3) PreventivePlan & ReliabilityAsset: Planos de revisão e MTBF! (｡•̀ᴗ-)✧
// ============================================================================

import '../core/format.dart';

// Representa uma máquina ou equipamento cadastrado no galpão :3
class AssetItem {
  const AssetItem({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    this.type,
    this.criticality,
    this.location,
    this.manufacturer,
    this.model,
    this.modelName,
    this.serialNumber,
    this.description,
    this.functionalLocationName,
    this.operatingHours = 0,
    this.operatingCycles = 0,
    this.createdAt,
  });

  factory AssetItem.fromJson(Map<String, dynamic> json) => AssetItem(
        id: toInt(json['id']),
        code: toText(json['asset_code']) ?? '',
        name: toText(json['name']) ?? '',
        status: toText(json['status']) ?? 'active',
        type: toText(json['asset_type']),
        criticality: toText(json['criticality']),
        location: toText(json['functional_location_name']) ?? toText(json['location']),
        manufacturer: toText(json['manufacturer']),
        model: toText(json['model']),
        modelName: toText(json['model_name']),
        serialNumber: toText(json['serial_number']),
        description: toText(json['description']),
        functionalLocationName: toText(json['functional_location_name']),
        operatingHours: toDouble(json['operating_hours']),
        operatingCycles: toDouble(json['operating_cycles']),
        createdAt: toDate(json['created_at']),
      );

  final int id;
  final String code;
  final String name;
  final String status;
  final String? type;
  final String? criticality;
  final String? location;
  final String? manufacturer;
  final String? model;
  final String? modelName;
  final String? serialNumber;
  final String? description;
  final String? functionalLocationName;
  final double operatingHours;
  final double operatingCycles;
  final DateTime? createdAt;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.type,
    required this.assetName,
    this.workOrderNumber,
    this.assetCode,
    this.description,
    this.dueAt,
    this.createdAt,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
        id: toInt(json['id']),
        title: toText(json['title']) ?? '',
        workOrderNumber: toText(json['work_order_number']),
        assetCode: toText(json['asset_code']),
        description: toText(json['description']),
        status: toText(json['status']) ?? 'open',
        priority: toText(json['priority']) ?? 'medium',
        type: toText(json['type']) ?? 'corrective',
        assetName: toText(json['asset_name']) ?? '',
        dueAt: toDate(json['due_at']),
        createdAt: toDate(json['created_at']),
      );

  final int id;
  final String title;
  final String? workOrderNumber;
  final String? assetCode;
  final String? description;
  final String status;
  final String priority;
  final String type;
  final String assetName;
  final DateTime? dueAt;
  final DateTime? createdAt;
}

class PreventivePlan {
  const PreventivePlan({
    required this.id,
    required this.assetId,
    required this.assetCode,
    required this.assetName,
    required this.title,
    this.frequencyDays,
    this.nextDueAt,
    this.status = 'active',
  });

  factory PreventivePlan.fromJson(Map<String, dynamic> json) => PreventivePlan(
        id: toInt(json['id']),
        assetId: toInt(json['asset_id']),
        assetCode: toText(json['asset_code']) ?? '',
        assetName: toText(json['asset_name']) ?? '',
        title: toText(json['name']) ?? toText(json['title']) ?? 'Plano preventivo',
        frequencyDays: json['frequency_days'] == null ? null : toInt(json['frequency_days']),
        nextDueAt: toDate(json['next_due_at']),
        status: toText(json['status']) ?? 'active',
      );

  final int id;
  final int assetId;
  final String assetCode;
  final String assetName;
  final String title;
  final int? frequencyDays;
  final DateTime? nextDueAt;
  final String status;
}

class ReliabilityAsset {
  const ReliabilityAsset({
    required this.id,
    required this.code,
    required this.name,
    this.failures = 0,
    this.downtimeHours = 0,
    this.calendarAvailability = 1.0,
    this.mttrHours,
  });

  factory ReliabilityAsset.fromJson(Map<String, dynamic> json) => ReliabilityAsset(
        id: toInt(json['id']),
        code: toText(json['asset_code']) ?? '',
        name: toText(json['name']) ?? '',
        failures: toInt(json['failures']),
        downtimeHours: toDouble(json['downtime_hours']),
        calendarAvailability: toDouble(json['calendar_availability']),
        mttrHours: json['mttr_hours'] == null ? null : toDouble(json['mttr_hours']),
      );

  final int id;
  final String code;
  final String name;
  final int failures;
  final double downtimeHours;
  final double calendarAvailability;
  final double? mttrHours;
}
