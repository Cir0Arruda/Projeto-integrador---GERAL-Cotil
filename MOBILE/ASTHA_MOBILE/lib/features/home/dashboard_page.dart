// ============================================================================
// ★ DASHBOARD PRINCIPAL DA OPERAÇÃO (DASHBOARD_PAGE.DART) ★
// A tela de visão geral que resume toda a saúde do estoque! (✿◠‿◠)
// 1) Chama a API GET /api/materials pra pegar todos os itens do armazém :3
// 2) Calcula totais, valor em R$, itens acabando e gráficos coloridos (｡•̀ᴗ-)✧
// 3) Mostra alertas de atenção imediata pros materiais que estão em falta ;-;
// ============================================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../state/session_controller.dart';
import '../../state/warehouse_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';
import '../../widgets/material_thumb.dart';
import '../shared/labels.dart';

// Classe que faz as continhas de matemática dos dados que vieram da API (o^▽^o)
class StockSummary {
  StockSummary(List<MaterialItem> items)
      : total = items.length,
        low = items.where((e) => e.level == StockLevel.low).length,
        empty = items.where((e) => e.level == StockLevel.empty).length,
        volume = items.fold(0, (sum, e) => sum + e.quantity),
        value = items.fold(0, (sum, e) => sum + e.totalValue),
        attention = items.where((e) => e.level != StockLevel.healthy).toList();

  final int total;
  final int low;
  final int empty;
  final double volume;
  final double value;
  final List<MaterialItem> attention;

  int get healthy => total - low - empty;
}

// O painel do dashboard com cartões e gráficos bonitinhos (｡•̀ᴗ-)✧
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Repositório que sabe chamar a API no servidor :3
    final repository = context.read<WmsRepository>();
    final user = context.watch<SessionController>().user;
    final warehouseId = context.read<WarehouseController>().selectedId;

    // Busca os materiais chamando a API do backend! ヽ(>∀<☆)ノ
    return AsyncView<List<MaterialItem>>(
      load: () => repository.materials(warehouseId: warehouseId),
      builder: (context, items) {
        final summary = StockSummary(items);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Olá, ${user?.displayName ?? ''}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (user?.orgName != null)
              Text(user!.orgName!, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            _StatGrid(summary: summary),
            const SizedBox(height: 16),
            _DistributionCard(summary: summary),
            const SizedBox(height: 16),
            _AttentionCard(items: summary.attention),
          ],
        );
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final StockSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(label: 'Materiais', value: '${summary.total}', icon: Icons.category_outlined),
      StatCard(
        label: 'Nível crítico',
        value: '${summary.low}',
        color: AppColors.warning,
        icon: Icons.warning_amber_outlined,
      ),
      StatCard(
        label: 'Zerados',
        value: '${summary.empty}',
        color: AppColors.danger,
        icon: Icons.block_outlined,
      ),
      StatCard(
        label: 'Volume total',
        value: formatQuantity(summary.volume),
        icon: Icons.stacked_bar_chart,
      ),
    ];
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: cards,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          width: double.infinity,
          child: StatCard(
            label: 'Valor em estoque',
            value: formatCurrency(summary.value),
            color: AppColors.brandDark,
            icon: Icons.payments_outlined,
          ),
        ),
      ],
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.summary});

  final StockSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('Saudável', summary.healthy, AppColors.brand),
      ('Crítico', summary.low, AppColors.warning),
      ('Zerado', summary.empty, AppColors.danger),
    ];
    return SectionCard(
      title: 'Distribuição do estoque',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: summary.total == 0
                  ? const Center(child: Text('Sem dados'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                        sections: [
                          for (final entry in entries)
                            if (entry.$2 > 0)
                              PieChartSectionData(
                                value: entry.$2.toDouble(),
                                color: entry.$3,
                                radius: 22,
                                showTitle: false,
                              ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: entry.$3, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.$1)),
                          Text('${entry.$2}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.items});

  final List<MaterialItem> items;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(10).toList();
    return SectionCard(
      title: 'Ação imediata',
      child: visible.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Todos os itens estão com estoque saudável.'),
            )
          : Column(
              children: [
                for (final item in visible)
                  ListTile(
                    leading: MaterialThumb(item: item, size: 42),
                    title: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.code),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatQuantity(item.quantity),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: stockLevelColor(item.level),
                          ),
                        ),
                        StatusPill(
                          label: stockLevelLabel(item.level),
                          color: stockLevelColor(item.level),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
