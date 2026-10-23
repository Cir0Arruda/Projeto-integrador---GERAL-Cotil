// ============================================================================
// ★ MODELOS DE INTELIGÊNCIA E ANALYTICS (ANALYTICS_MODELS.DART) ★
// Estruturas de dados para pesquisas estatísticas e métodos matemáticos:
// 1) AnalyticsStudy: Pergunta de negócio, hipótese e status da pesquisa :3
// 2) AnalyticsMethod: Fórmula ou algoritmo disponível no catálogo (✿◠‿◠)
// ============================================================================

import '../core/format.dart';

// Representa um estudo analítico aberto no armazém :3
class AnalyticsStudy {
  const AnalyticsStudy({
    required this.id,
    required this.name,
    required this.question,
    required this.status,
    this.createdAt,
  });

  factory AnalyticsStudy.fromJson(Map<String, dynamic> json) => AnalyticsStudy(
        id: toInt(json['id']),
        name: toText(json['name']) ?? 'Estudo :3',
        question: toText(json['question']) ?? '',
        status: toText(json['status']) ?? 'active',
        createdAt: toDate(json['created_at']),
      );

  final int id;
  final String name;
  final String question;
  final String status;
  final DateTime? createdAt;
}

// Representa um método ou modelo estatístico do catálogo (｡•̀ᴗ-)✧
class AnalyticsMethod {
  const AnalyticsMethod({
    required this.id,
    required this.kind,
    required this.label,
    required this.status,
  });

  factory AnalyticsMethod.fromJson(Map<String, dynamic> json) => AnalyticsMethod(
        id: toText(json['id']) ?? '',
        kind: toText(json['kind']) ?? '',
        label: toText(json['label']) ?? '',
        status: toText(json['status']) ?? 'exploratory',
      );

  final String id;
  final String kind;
  final String label;
  final String status;
}
