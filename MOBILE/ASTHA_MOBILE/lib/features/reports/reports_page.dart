// ============================================================================
// ★ PROJETO INTEGRADOR - TÂNIA BASSO (21/OUT) ★
// REQUISITO CUMPRIDO AQUI (SEGUNDA TELA DE EXEMPLO):
// 1) Chamada à API no contexto do projeto: repository.movements() chama GET /api/movements :3
// 2) Tela que mostra uma lista de objetos vindos da API: ListView com os MovementRecord (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cards.dart';

// Telinha de relatórios e histórico de tudo que entrou e saiu do galpão (✿◠‿◠)
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Filtro de abas: null = todas, true = só entradas, false = só saídas :3
  bool? _entries;
  // O que a pessoa escreveu na busca pra filtrar por material, código ou quem pegou (TwT)
  String _search = '';

  @override
  Widget build(BuildContext context) {
    // Pega o repositório WMS que conversa diretamente com a nossa API! (｡•̀ᴗ-)✧
    final repository = context.read<WmsRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios de Movimentação'),
      ),
      body: Column(
        children: [
          // Botoõezinhos segmentados no topo pra filtrar Todas / Entradas / Saídas :3
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<bool?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Todas')),
                ButtonSegment(value: true, label: Text('Entradas')),
                ButtonSegment(value: false, label: Text('Saídas')),
              ],
              selected: {_entries},
              onSelectionChanged: (value) => setState(() => _entries = value.first),
            ),
          ),
          // Caixinha de texto pra pesquisar por texto em tempo real (o^▽^o)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Buscar por material, código ou responsável...',
                isDense: true,
              ),
              onChanged: (val) => setState(() => _search = val.toLowerCase().trim()),
            ),
          ),

          // ==================================================================
          // ★ REQUISITO DA TÂNIA: CHAMADA À API E LISTA DE OBJETOS ★
          // 1. Chamada: repository.movements(...) dispara GET /api/movements
          // 2. Lista: Renderiza cada objeto MovementRecord vindo da API! :3
          // ==================================================================
          Expanded(
            child: AsyncView<List<MovementRecord>>(
              key: ValueKey(_entries),
              // Faz a requisição assíncrona HTTP pra API no backend (づ｡◕‿‿◕｡)づ
              load: () => repository.movements(entries: _entries),
              builder: (context, records) {
                final filtered = _search.isEmpty
                    ? records
                    : records.where((r) {
                        final desc = r.materialDescription.toLowerCase();
                        final code = r.materialCode.toLowerCase();
                        final resp = (r.responsible ?? '').toLowerCase();
                        return desc.contains(_search) || code.contains(_search) || resp.contains(_search);
                      }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(message: 'Nenhuma movimentação encontrada.');
                }

                final entriesCount = records.where((r) => r.isEntry).length;
                final exitsCount = records.where((r) => !r.isEntry).length;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Registros', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text('${records.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Entradas', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text('$entriesCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brand)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Saídas', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 2),
                                Text('$exitsCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...filtered.map((record) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MovementTile(record: record),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.record});

  final MovementRecord record;

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.isEntry ? 'Entrada de estoque' : 'Saída de estoque',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              InfoRow(label: 'Material', value: '${record.materialDescription} (${record.materialCode})'),
              InfoRow(label: 'Quantidade', value: '${record.isEntry ? '+' : '-'}${formatQuantity(record.quantity)}'),
              if (record.responsible != null && record.responsible!.isNotEmpty)
                InfoRow(label: 'Responsável', value: record.responsible),
              if (record.nfNumber != null && record.nfNumber!.isNotEmpty)
                InfoRow(label: 'Nota Fiscal / Documento', value: record.nfNumber),
              if (record.reason != null && record.reason!.isNotEmpty)
                InfoRow(label: 'Motivo', value: record.reason),
              if (record.notes != null && record.notes!.isNotEmpty)
                InfoRow(label: 'Observações', value: record.notes),
              InfoRow(label: 'Data e hora', value: formatDateTime(record.createdAt)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = record.isEntry ? AppColors.brand : AppColors.danger;
    final details = [
      record.materialCode,
      if (record.responsible != null) record.responsible!,
      formatDateTime(record.createdAt),
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(record.isEntry ? Icons.south_west : Icons.north_east, color: color, size: 20),
        ),
        title: Text(record.materialDescription, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '${record.isEntry ? '+' : '-'}${formatQuantity(record.quantity)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
        onTap: () => _showDetails(context),
      ),
    );
  }
}
