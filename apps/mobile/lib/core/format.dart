// ============================================================================
// ★ FORMATADORES DE DADOS E NÚMEROS (FORMAT.DART) ★
// Pequenas funções utilitárias que deixam números, moedas e datas
// perfeitamente legíveis no padrão brasileiro (R$, vírgula, dia/mês/ano)! (✿◠‿◠)
// ============================================================================

import 'package:intl/intl.dart';

// Converte qualquer valor vindo do JSON em double seguro sem estourar erro :3
double toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

// Converte qualquer número em inteiro arredondado (｡•̀ᴗ-)✧
int toInt(dynamic value) => toDouble(value).round();

// Limpa strings e converte textos vazios em null pra ficar limpo no banco :3
String? toText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

// Converte textos ISO em DateTime local com fuso horário certinho (*¯︶¯*)
DateTime? toDate(dynamic value) {
  final text = toText(value);
  if (text == null) return null;
  return DateTime.tryParse(text)?.toLocal();
}

// Formata quantidade de estoque: se for 10.0 vira '10', se tiver fração vira '10,5' :3
String formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return NumberFormat('#,##0.###', 'pt_BR').format(value);
}

// Formata valores monetários bonitinhos (R$ 1.500,00, US$ ou €) (✿◠‿◠)
String formatCurrency(double value, {String currency = 'BRL'}) {
  final symbol = switch (currency) {
    'USD' => r'US$',
    'EUR' => '€',
    _ => r'R$',
  };
  return NumberFormat.currency(locale: 'pt_BR', symbol: symbol).format(value);
}

// Formata data e hora no estilo brasileiro: 15/10/2026 19:30 (｡•̀ᴗ-)✧
String formatDateTime(DateTime? value) =>
    value == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(value);

// Formata apenas o dia/mês/ano: 15/10/2026 :3
String formatDate(DateTime? value) =>
    value == null ? '—' : DateFormat('dd/MM/yyyy').format(value);

// Converte texto digitado com vírgula pelo usuário em número decimal válido (*¯︶¯*)
double? parseDecimal(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  return value != null && value.isFinite ? value : null;
}
