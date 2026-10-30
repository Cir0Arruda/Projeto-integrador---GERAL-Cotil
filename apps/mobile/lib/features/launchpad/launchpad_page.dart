// ============================================================================
// ★ PAINEL LAUNCHPAD PRINCIPAL (LAUNCHPAD_PAGE.DART) ★
// A central de comando supremo do RAVEN ASTHA! (✿◠‿◠)
// Dispara 5 chamadas à API simultaneamente em paralelo com Future.wait:
// 1) GET /api/materials: estoque de materiais :3
// 2) GET /api/movements: histórico de entradas e saídas (｡•̀ᴗ-)✧
// 3) GET /api/eam/assets: máquinas e ativos
// 4) GET /api/eam/work-orders: ordens de serviço abertas
// 5) GET /api/warehouses/:id/insights: recomendações inteligentes do armazém! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/eam_models.dart';
import '../../models/wms_models.dart';
import '../../repositories/eam_repository.dart';
import '../../repositories/wms_repository.dart';
import '../../state/session_controller.dart';
import '../../state/warehouse_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';
import '../../widgets/warehouse_selector.dart';
import '../analytics/analytics_page.dart';
import '../components/components_page.dart';
import '../eam/eam_page.dart';
import '../reports/reports_page.dart';
import '../stock/stock_page.dart';

// Pacotinho com todos os dados que vieram das 5 APIs juntas! :3
class LaunchpadData {
  const LaunchpadData({
    required this.materials,
    required this.movements,
    required this.assets,
    required this.orders,
    this.insights,
  });

  final List<MaterialItem> materials;
  final List<MovementRecord> movements;
  final List<AssetItem> assets;
  final List<WorkOrder> orders;
  final StockInsights? insights;
}

class LaunchpadPage extends StatefulWidget {
  const LaunchpadPage({super.key});

  @override
  State<LaunchpadPage> createState() => _LaunchpadPageState();
}

class _LaunchpadPageState extends State<LaunchpadPage> {
  int _viewIndex = 0;
  int _reloadKey = 0;

  Future<LaunchpadData> _loadData(BuildContext context) async {
    final wmsRepo = context.read<WmsRepository>();
    final eamRepo = context.read<EamRepository>();
    final warehouseId = context.read<WarehouseController>().selectedId;

    final results = await Future.wait([
      wmsRepo.materials(warehouseId: warehouseId),
      wmsRepo.movements(),
      eamRepo.assets(),
      eamRepo.workOrders(),
      if (warehouseId != null)
        wmsRepo
            .stockInsights(warehouseId)
            .catchError((_) => const StockInsights())
      else
        Future.value(const StockInsights()),
    ]);

    final movementsList = results[1] as List<MovementRecord>;

    return LaunchpadData(
      materials: results[0] as List<MaterialItem>,
      movements: movementsList.take(6).toList(),
      assets: results[2] as List<AssetItem>,
      orders: results[3] as List<WorkOrder>,
      insights: results[4] as StockInsights?,
    );
  }

  void _navigate(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final warehouseCtrl = context.watch<WarehouseController>();

    return KeyedSubtree(
      key: ValueKey('$_reloadKey-${warehouseCtrl.selectedId}'),
      child: AsyncView<LaunchpadData>(
        revision: context.select<ApiClient, int>((api) => api.dataRevision),
        load: () => _loadData(context),
        builder: (context, data) {
          return RefreshIndicator(
            onRefresh: () async => setState(() => _reloadKey++),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                _buildViewSelector(),
                const SizedBox(height: 16),
                if (_viewIndex == 0) ...[
                  _buildOverviewKpis(data),
                  const SizedBox(height: 16),
                  _buildAttentionSection(data.materials),
                  const SizedBox(height: 16),
                  _buildOrdersSection(data.orders),
                  const SizedBox(height: 16),
                  _buildRecentMovementsSection(data.movements),
                  const SizedBox(height: 16),
                  _buildModulesGrid(context),
                ] else ...[
                  _buildStockInsightsView(data.insights, warehouseCtrl),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<SessionController>().user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LAUNCHPAD',
                    style: TextStyle(
                      color: AppColors.brandText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Visão geral da operação',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Atualizar dados',
              onPressed: () => setState(() => _reloadKey++),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Painel de operação',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Olá, ${user?.displayName ?? 'Usuário'}. Seu estoque, prioridades e manutenção em um só lugar.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildViewSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _viewIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.dashboard_outlined,
                        size: 16,
                        color: _viewIndex == 0
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Visão geral',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _viewIndex == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _viewIndex == 0
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _viewIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.insights_outlined,
                        size: 16,
                        color: _viewIndex == 1
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Visão dos estoques',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _viewIndex == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _viewIndex == 1
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewKpis(LaunchpadData data) {
    final lowStock = data.materials.where((m) => m.quantity <= m.minQty).length;
    final openOrders = data.orders
        .where((o) => o.status != 'completed' && o.status != 'cancelled')
        .length;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildKpiCard(
          title: 'Materiais',
          value: '${data.materials.length}',
          subtitle: 'Itens cadastrados',
          icon: Icons.inventory_2_outlined,
          color: AppColors.brand,
        ),
        _buildKpiCard(
          title: 'No mínimo/abaixo',
          value: '$lowStock',
          subtitle: 'Exigem atenção',
          icon: Icons.warning_amber_rounded,
          color: lowStock > 0 ? AppColors.danger : AppColors.textMuted,
        ),
        _buildKpiCard(
          title: 'Ativos',
          value: '${data.assets.length}',
          subtitle: 'Máquinas e equip.',
          icon: Icons.precision_manufacturing_outlined,
          color: AppColors.purple,
        ),
        _buildKpiCard(
          title: 'Ordens abertas',
          value: '$openOrders',
          subtitle: 'Em andamento',
          icon: Icons.assignment_outlined,
          color: openOrders > 0 ? AppColors.warning : AppColors.textMuted,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color == AppColors.danger
                  ? AppColors.danger
                  : AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionSection(List<MaterialItem> items) {
    final lowStockItems = items
        .where((m) => m.quantity <= m.minQty)
        .take(5)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Estoque que precisa de atenção',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _navigate(const StockPage()),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Ver estoque →',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Nenhum material em nível crítico.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lowStockItems.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final item = lowStockItems[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.code,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${formatQuantity(item.quantity)} / mín. ${formatQuantity(item.minQty)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrdersSection(List<WorkOrder> orders) {
    final activeOrders = orders
        .where((o) => o.status != 'completed' && o.status != 'cancelled')
        .take(5)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ordens em andamento',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _navigate(const EamPage()),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Ver ordens →',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (activeOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Nenhuma ordem de serviço pendente.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeOrders.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final order = activeOrders[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            order.workOrderNumber ?? '#${order.id}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: order.status,
                      color: order.status == 'in_progress'
                          ? AppColors.brand
                          : AppColors.warning,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentMovementsSection(List<MovementRecord> movements) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.swap_vert, size: 18, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Movimentações recentes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _navigate(const ReportsPage()),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Relatórios →',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Nenhuma movimentação registrada.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: movements.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final m = movements[index];
                final isEntry = m.isEntry;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isEntry
                            ? AppColors.brand.withValues(alpha: 0.1)
                            : AppColors.danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isEntry ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: isEntry ? AppColors.brand : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.materialDescription.isNotEmpty
                                ? m.materialDescription
                                : m.materialCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${m.responsible ?? 'Sistema'} · ${formatDateTime(m.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isEntry ? '+' : '-'}${formatQuantity(m.quantity)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isEntry ? AppColors.brand : AppColors.danger,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildModulesGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Módulos da plataforma',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            _buildModuleCard(
              title: 'WMS Core',
              subtitle: 'Estoque e mapa',
              icon: Icons.inventory_2_outlined,
              onTap: () => _navigate(const StockPage()),
            ),
            _buildModuleCard(
              title: 'Componentes',
              subtitle: 'Conjuntos e BOM',
              icon: Icons.account_tree_outlined,
              onTap: () => _navigate(const ComponentsPage()),
            ),
            _buildModuleCard(
              title: 'Ativos & EAM',
              subtitle: 'Máquinas e ordens',
              icon: Icons.build_outlined,
              onTap: () => _navigate(const EamPage()),
            ),
            _buildModuleCard(
              title: 'Análises',
              subtitle: 'Estudos e métricas',
              icon: Icons.insights_outlined,
              onTap: () => _navigate(const AnalyticsPage()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInsightsView(
    StockInsights? insights,
    WarehouseController warehouseCtrl,
  ) {
    final stockData = insights ?? const StockInsights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Visão dos estoques',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const WarehouseSelector(),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildKpiCard(
              title: 'Valor em estoque',
              value: formatCurrency(stockData.stockValue),
              subtitle: 'Patrimônio alocado',
              icon: Icons.attach_money,
              color: AppColors.brand,
            ),
            _buildKpiCard(
              title: 'Itens cadastrados',
              value: '${stockData.totalMaterials}',
              subtitle: 'Variedade do armazém',
              icon: Icons.category_outlined,
              color: AppColors.textPrimary,
            ),
            _buildKpiCard(
              title: 'No mínimo ou zero',
              value: '${stockData.criticalCount + stockData.zeroCount}',
              subtitle: 'Reposição necessária',
              icon: Icons.warning_amber_rounded,
              color: (stockData.criticalCount + stockData.zeroCount) > 0
                  ? AppColors.danger
                  : AppColors.textMuted,
            ),
            _buildKpiCard(
              title: 'Volume total',
              value: formatQuantity(stockData.totalQuantity),
              subtitle: 'Unidades armazenadas',
              icon: Icons.stacked_bar_chart,
              color: AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Itens críticos deste armazém',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (stockData.criticalItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Nenhum item em nível crítico no armazém selecionado.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stockData.criticalItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final item = stockData.criticalItems[index];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${item.code} · ${item.brand ?? item.sector ?? 'Material'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${formatQuantity(item.quantity)} ${item.unit}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                              ),
                            ),
                            Text(
                              'mín. ${formatQuantity(item.minQty)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
