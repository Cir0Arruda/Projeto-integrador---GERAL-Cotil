// ============================================================================
// ★ PROJETO INTEGRADOR - TÂNIA BASSO (21/OUT) ★
// REQUISITO CUMPRIDO AQUI:
// 1) Chamada à API no contexto do projeto: repository.materials() chama GET /api/materials :3
// 2) Tela que mostra uma lista de objetos vindos da API: ListView com os MaterialItem (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../state/warehouse_controller.dart';
import '../../widgets/async_view.dart';
import '../../widgets/material_thumb.dart';
import '../shared/labels.dart';
import 'material_detail_sheet.dart';
import 'material_form_dialog.dart';

// Essa é a telinha principal do estoque onde a mágica acontece (✿◠‿◠)
// Ela carrega os dados do servidor e monta a lista de materiais todinha na tela!
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  // Guarda o textinho que a pessoa digitou na barra de pesquisa pra filtrar :3
  String _query = '';

  // Chavezinha esperta pra mandar a tela recarregar e buscar os dados fresquinhos na API (TwT)
  int _reloadKey = 0;

  // Funçãozinha pra atualizar a tela quando a gente cadastra ou edita algo ;-;
  void _refresh() => setState(() => _reloadKey++);

  // Essa função vê se o material combina com o que foi digitado na busca (o^▽^o)
  // Ela procura no código, nome, marca, máquina, localização... em tudo!
  bool _matches(MaterialItem item) {
    if (_query.isEmpty) return true;
    final haystack = [
      item.code,
      item.description,
      item.brand,
      item.model,
      item.location,
      item.barcode,
      item.machinery,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  // Abre a janelinha modal pra cadastrar um novo material no estoque :3
  // Quando fecha com sucesso, ela recarrega a lista chamando a API de novo!
  Future<void> _openCreateDialog() async {
    final created = await MaterialFormDialog.show(context);
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Pega o repositório que sabe falar com a API lá no servidor (づ｡◕‿‿◕｡)づ
    final repository = context.read<WmsRepository>();
    // Pega o armazém selecionado atualmente pra filtrar certinho
    final warehouseId = context.read<WarehouseController>().selectedId;

    return Scaffold(
      body: Column(
        children: [
          // Campo de busca bonitinho no topo pra achar qualquer item rapidinho
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por código, descrição, marca ou máquina',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openCreateDialog,
                  tooltip: 'Novo Material',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // ==================================================================
          // ★ AQUI ESTÁ O CORAÇÃO DO REQUISITO DA TÂNIA! ★
          // 1. Chamada à API: repository.materials(warehouseId: ...) dispara um GET /api/materials
          // 2. Lista de Objetos: O ListView.separated abaixo desenha CADA OBJETO vindo da API!
          // ==================================================================
          Expanded(
            child: AsyncView<List<MaterialItem>>(
              key: ValueKey(_reloadKey),
              // Faz a chamada assíncrona HTTP pra API no servidor buscar a lista :3
              load: () => repository.materials(warehouseId: warehouseId),
              builder: (context, items) {
                // Filtra os itens se o usuário digitou algo na caixinha de busca
                final visible = items.where(_matches).toList();
                
                // Se o servidor respondeu vazio ou a busca não achou nada, avisa com carinho (;-;)
                if (visible.isEmpty) {
                  return const EmptyState(message: 'Nenhum material encontrado.');
                }

                // Renderiza a lista de objetos retornados da API na tela com rolagem suave (｡•̀ᴗ-)✧
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _MaterialTile(
                    item: visible[index],
                    onChanged: _refresh,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Botão flutuante fofo pra adicionar um novo item no estoque :3
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Material', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// Esse widget representa CADA CARTÃOZINHO da lista que veio da API (*¯︶¯*)
// Ele mostra a foto, nome, código e a quantidade em estoque com cores dinâmicas!
class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.item, required this.onChanged});

  final MaterialItem item; // Objeto de dados vindo direto do JSON da API!
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // Escolhe a cor: verde se tá suave, amarelo se tá acabando e vermelho se zerou (TwT)
    final color = stockLevelColor(item.level);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // Miniatura da foto do material cadastrada no sistema
        leading: MaterialThumb(item: item),
        title: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [item.code, item.brand, item.location].whereType<String>().join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Quantidade numérica e unidade de medida (ex: 50 UN)
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatQuantity(item.quantity),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            Text(item.unit, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        // Clicar no cartãozinho abre os detalhes completos do item (｡•̀ᴗ-)✧
        onTap: () async {
          final changed = await MaterialDetailSheet.show(context, item);
          if (changed == true) onChanged();
        },
      ),
    );
  }
}
