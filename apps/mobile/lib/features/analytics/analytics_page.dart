// ============================================================================
// ★ PAINEL DE ESTUDOS ANALÍTICOS E INSIGHTS (ANALYTICS_PAGE.DART) ★
// Aqui a inteligência do sistema entra em ação! (✿◠‿◠)
// 1) Aba de Estudos: chama GET /api/analytics/studies pra listar pesquisas de peças :3
// 2) Cria novos estudos com POST /api/analytics/studies (｡•̀ᴗ-)✧
// 3) Aba de Insights: chama GET /api/analytics/insights trazendo dicas da IA! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/analytics_models.dart';
import '../../repositories/analytics_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';

// Telinha de estudos analíticos da operação :3
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createNewStudy() async {
    final nameCtrl = TextEditingController();
    final questionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Novo estudo analítico', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome do estudo *',
                    hintText: 'Ex.: Vida útil dos rolamentos da esteira 02',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome do estudo.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: questionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pergunta do estudo *',
                    hintText: 'Ex.: Qual é o tempo médio até falha e a probabilidade de falha em 1000h?',
                  ),
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe a pergunta de pesquisa.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await context.read<AnalyticsRepository>().createStudy(
                      nameCtrl.text.trim(),
                      questionCtrl.text.trim(),
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop(true);
              } catch (e) {
                if (dialogCtx.mounted) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    SnackBar(content: Text('Erro ao criar estudo: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Criar estudo'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    questionCtrl.dispose();

    if (created == true && mounted) {
      setState(() => _revision++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estudo criado no Estúdio de Análises.')),
      );
    }
  }

  void _showStudyDetail(AnalyticsStudy study) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ESTUDO REPRODUZÍVEL',
                      style: TextStyle(
                        color: AppColors.brandText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (study.createdAt != null)
                    Text(formatDate(study.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              Text(study.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Pergunta de pesquisa:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  study.question,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              InfoRow(label: 'Identificador único', value: '${study.id}'),
              const SizedBox(height: 16),
              const Text(
                'Métodos aplicáveis a este estudo:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _buildMethodChip('Kaplan–Meier', 'Sobrevivência empírica'),
              const SizedBox(height: 6),
              _buildMethodChip('Weibull 2P', 'Ajuste paramétrico e confiabilidade'),
              const SizedBox(height: 6),
              _buildMethodChip('Análise de Pareto', 'Perdas e causas raízes'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AnalyticsRepository>();
    final canCreate = context.select<SessionController, bool>((s) => s.user?.canMove ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estúdio de Análises'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Seus estudos'),
            Tab(text: 'Catálogo de métodos'),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _createNewStudy,
              icon: const Icon(Icons.add),
              label: const Text('Novo estudo'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          KeyedSubtree(
            key: ValueKey('studies-$_revision'),
            child: AsyncView<List<AnalyticsStudy>>(
              load: repo.studies,
              builder: (context, studies) {
                if (studies.isEmpty) {
                  return const EmptyState(
                    message: 'Nenhum estudo cadastrado ainda. Crie seu primeiro estudo de confiabilidade.',
                    icon: Icons.biotech_outlined,
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: studies.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final study = studies[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.science_outlined, color: AppColors.brandText, size: 22),
                        ),
                        title: Text(study.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(study.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (study.createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Criado em: ${formatDate(study.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                        onTap: () => _showStudyDetail(study),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          AsyncView<List<AnalyticsMethod>>(
            load: repo.catalog,
            builder: (context, methods) {
              if (methods.isEmpty) {
                return const EmptyState(
                  message: 'Catálogo de métodos em carregamento.',
                  icon: Icons.menu_book_outlined,
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: methods.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final method = methods[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.show_chart, color: AppColors.textMain, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(method.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  'Tipo: ${method.kind} · Status: ${method.status}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
