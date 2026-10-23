// ============================================================================
// ★ MÓDULO EAM - GESTÃO DE ATIVOS E MANUTENÇÃO (EAM_PAGE.DART) ★
// Cuida de todas as máquinas, empilhadeiras e equipamentos da fábrica! (✿◠‿◠)
// 1) Ordens de Serviço: consertos e manutenções chamando GET /api/eam/work-orders :3
// 2) Ativos: lista todas as máquinas do galpão chamando GET /api/eam/assets (｡•̀ᴗ-)✧
// 3) Preventivas: cronograma de revisões agendadas chamando GET /api/eam/preventives
// 4) Confiabilidade: métricas industriais (MTBF e MTTR) chamando GET /api/eam/metrics! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/eam_models.dart';
import '../../repositories/eam_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';
import '../../widgets/dialogs.dart';
import '../shared/labels.dart';

// A tela principal com as 4 abas industriais :3
class EamPage extends StatelessWidget {
  const EamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: const [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Ordens de serviço'),
              Tab(text: 'Ativos'),
              Tab(text: 'Preventivas'),
              Tab(text: 'Confiabilidade'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _WorkOrdersTab(),
                _AssetsTab(),
                _PreventivesTab(),
                _ReliabilityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkOrdersTab extends StatefulWidget {
  const _WorkOrdersTab();

  @override
  State<_WorkOrdersTab> createState() => _WorkOrdersTabState();
}

class _WorkOrdersTabState extends State<_WorkOrdersTab> with AutomaticKeepAliveClientMixin {
  int _revision = 0;

  @override
  bool get wantKeepAlive => true;

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WorkOrderSheet(),
    );
    if (created == true && mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final repository = context.read<EamRepository>();
    final canWrite = context.select<SessionController, bool>((s) => s.user?.canMove ?? false);

    return Column(
      children: [
        if (canWrite)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('NOVA ORDEM DE SERVIÇO'),
              ),
            ),
          ),
        Expanded(
          child: AsyncView<List<WorkOrder>>(
            key: ValueKey(_revision),
            load: repository.workOrders,
            builder: (context, orders) {
              if (orders.isEmpty) return const EmptyState(message: 'Nenhuma ordem de serviço.');
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _WorkOrderTile(order: orders[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkOrderTile extends StatelessWidget {
  const _WorkOrderTile({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.workOrderNumber ?? '#${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                StatusPill(
                  label: workStatusLabel(order.status),
                  color: workStatusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              order.assetName,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    workTypeLabel(order.type),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor(order.priority).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priorityLabel(order.priority),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor(order.priority),
                    ),
                  ),
                ),
                const Spacer(),
                if (order.createdAt != null)
                  Text(
                    formatDate(order.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetsTab extends StatefulWidget {
  const _AssetsTab();

  @override
  State<_AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends State<_AssetsTab> with AutomaticKeepAliveClientMixin {
  int _revision = 0;

  @override
  bool get wantKeepAlive => true;

  Future<void> _recordCounter(AssetItem asset) async {
    final hoursCtrl = TextEditingController(text: asset.operatingHours > 0 ? asset.operatingHours.toString() : '');
    final cyclesCtrl = TextEditingController(text: asset.operatingCycles > 0 ? asset.operatingCycles.toString() : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Leitura de medidores: ${asset.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: hoursCtrl,
              decoration: const InputDecoration(labelText: 'Horímetro acumulado (horas)', hintText: 'Ex.: 1500.5'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cyclesCtrl,
              decoration: const InputDecoration(labelText: 'Ciclos acumulados', hintText: 'Ex.: 45000'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final hours = double.tryParse(hoursCtrl.text.trim());
              final cycles = double.tryParse(cyclesCtrl.text.trim());
              try {
                await context.read<EamRepository>().recordCounter(
                      assetId: asset.id,
                      hours: hours,
                      cycles: cycles,
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text('Falha ao registrar: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Salvar leitura'),
          ),
        ],
      ),
    );

    hoursCtrl.dispose();
    cyclesCtrl.dispose();

    if (confirmed == true && mounted) {
      setState(() => _revision++);
    }
  }

  void _showAsset(BuildContext context, AssetItem asset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(asset.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(asset.code, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              StatusPill(
                label: assetStatusLabel(asset.status),
                color: assetStatusColor(asset.status),
              ),
              const SizedBox(height: 16),
              InfoRow(label: 'Tipo', value: asset.type),
              InfoRow(label: 'Criticidade', value: asset.criticality),
              InfoRow(label: 'Localização', value: asset.location),
              InfoRow(label: 'Localização Funcional', value: asset.functionalLocationName),
              InfoRow(label: 'Fabricante', value: asset.manufacturer),
              InfoRow(label: 'Modelo', value: asset.modelName ?? asset.model),
              InfoRow(label: 'Número de série', value: asset.serialNumber),
              if (asset.operatingHours > 0)
                InfoRow(label: 'Horímetro atual', value: '${asset.operatingHours} h'),
              if (asset.operatingCycles > 0)
                InfoRow(label: 'Ciclos atuais', value: '${asset.operatingCycles}'),
              if (asset.description != null && asset.description!.trim().isNotEmpty)
                InfoRow(label: 'Descrição', value: asset.description),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _recordCounter(asset);
                  },
                  icon: const Icon(Icons.speed, size: 18),
                  label: const Text('REGISTRAR HORÍMETRO / CICLOS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final repository = context.read<EamRepository>();
    return AsyncView<List<AssetItem>>(
      key: ValueKey(_revision),
      load: repository.assets,
      builder: (context, assets) {
        if (assets.isEmpty) return const EmptyState(message: 'Nenhum ativo cadastrado.');
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: assets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final asset = assets[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.precision_manufacturing_outlined, color: AppColors.textMain),
                ),
                title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    asset.code,
                    asset.location,
                    if (asset.operatingHours > 0) '${asset.operatingHours}h',
                  ].whereType<String>().join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: StatusPill(
                  label: assetStatusLabel(asset.status),
                  color: assetStatusColor(asset.status),
                ),
                onTap: () => _showAsset(context, asset),
              ),
            );
          },
        );
      },
    );
  }
}

class _PreventivesTab extends StatelessWidget {
  const _PreventivesTab();

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EamRepository>();

    return AsyncView<List<PreventivePlan>>(
      load: repository.preventivePlans,
      builder: (context, plans) {
        if (plans.isEmpty) {
          return const EmptyState(
            message: 'Nenhum plano preventivo cadastrado.',
            icon: Icons.event_note_outlined,
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final plan = plans[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            plan.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill(
                          label: plan.status == 'active' ? 'Ativo' : 'Inativo',
                          color: plan.status == 'active' ? AppColors.brand : AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Equipamento: ${plan.assetName} (${plan.assetCode})',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (plan.frequencyDays != null) ...[
                          const Icon(Icons.repeat, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'A cada ${plan.frequencyDays} dias',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (plan.nextDueAt != null) ...[
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Próxima: ${formatDate(plan.nextDueAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReliabilityTab extends StatelessWidget {
  const _ReliabilityTab();

  @override
  Widget build(BuildContext context) {
    final repository = context.read<EamRepository>();

    return AsyncView<List<ReliabilityAsset>>(
      load: repository.reliabilityAssets,
      builder: (context, assets) {
        if (assets.isEmpty) {
          return const EmptyState(
            message: 'Nenhum indicador de confiabilidade disponível.',
            icon: Icons.analytics_outlined,
          );
        }

        final totalFailures = assets.fold(0, (sum, a) => sum + a.failures);
        final totalDowntime = assets.fold(0.0, (sum, a) => sum + a.downtimeHours);
        final avgAvailability = assets.isEmpty
            ? 0.0
            : (assets.fold(0.0, (sum, a) => sum + a.calendarAvailability) / assets.length) * 100;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  title: 'Disponibilidade',
                  value: '${avgAvailability.toStringAsFixed(1)}%',
                  subtitle: 'Média de operação',
                  color: avgAvailability >= 90 ? AppColors.brand : AppColors.warning,
                  icon: Icons.check_circle_outline,
                ),
                _buildMetricCard(
                  title: 'Falhas registradas',
                  value: '$totalFailures',
                  subtitle: 'Total de ocorrências',
                  color: totalFailures > 0 ? AppColors.danger : AppColors.brand,
                  icon: Icons.report_problem_outlined,
                ),
                _buildMetricCard(
                  title: 'Horas de parada',
                  value: '${totalDowntime.toStringAsFixed(1)} h',
                  subtitle: 'Indisponibilidade',
                  color: AppColors.warning,
                  icon: Icons.access_time_outlined,
                ),
                _buildMetricCard(
                  title: 'Ativos medidos',
                  value: '${assets.length}',
                  subtitle: 'Equipamentos monitorados',
                  color: AppColors.purple,
                  icon: Icons.precision_manufacturing_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Indicadores por equipamento',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = assets[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                a.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (a.calendarAvailability >= 0.9 ? AppColors.brand : AppColors.warning)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(a.calendarAvailability * 100).toStringAsFixed(1)}% disp.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: a.calendarAvailability >= 0.9 ? AppColors.brand : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(a.code, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Falhas: ${a.failures}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            Text(
                              'Downtime: ${a.downtimeHours.toStringAsFixed(1)} h',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            if (a.mttrHours != null)
                              Text(
                                'MTTR: ${a.mttrHours!.toStringAsFixed(1)} h',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
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
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _WorkOrderSheet extends StatefulWidget {
  const _WorkOrderSheet();

  @override
  State<_WorkOrderSheet> createState() => _WorkOrderSheetState();
}

class _WorkOrderSheetState extends State<_WorkOrderSheet> {
  static const _types = ['corrective', 'preventive', 'inspection'];
  static const _priorities = ['low', 'medium', 'high', 'critical'];

  final _title = TextEditingController();
  final _description = TextEditingController();
  late final Future<List<AssetItem>> _assets = context.read<EamRepository>().assets();

  AssetItem? _asset;
  String _type = 'corrective';
  String _priority = 'medium';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final asset = _asset;
    final title = _title.text.trim();
    if (asset == null || title.isEmpty) {
      showToast(context, 'Informe o ativo e o título.', error: true);
      return;
    }
    final repository = context.read<EamRepository>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await repository.createWorkOrder(
        assetId: asset.id,
        title: title,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        type: _type,
        priority: _priority,
      );
      navigator.pop(true);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nova ordem de serviço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              FutureBuilder<List<AssetItem>>(
                future: _assets,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const [];
                  return DropdownButtonFormField<AssetItem>(
                    initialValue: _asset,
                    decoration: const InputDecoration(labelText: 'Ativo'),
                    items: items
                        .map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.code})')))
                        .toList(),
                    onChanged: (value) => setState(() => _asset = value),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título do serviço'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: _types
                          .map((t) => DropdownMenuItem(value: t, child: Text(workTypeLabel(t))))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Prioridade'),
                      items: _priorities
                          .map((p) => DropdownMenuItem(value: p, child: Text(priorityLabel(p))))
                          .toList(),
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('CRIAR ORDEM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
