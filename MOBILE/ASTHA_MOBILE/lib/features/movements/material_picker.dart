// ============================================================================
// ★ SELETOR POPUP DE MATERIAIS (MATERIAL_PICKER.DART) ★
// Modal deslizante de baixo para cima para escolher um item do estoque:
// 1) Busca em tempo real por código ou descrição da peça :3
// 2) Exibe miniatura da foto, código e quantidade disponível em estoque (✿◠‿◠)
// 3) Retorna o material selecionado para o formulário de movimentação! (｡•̀ᴗ-)✧
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

// Abre a gavetinha bonitinha para escolher um material no galpão :3
Future<MaterialItem?> showMaterialPicker(BuildContext context) {
  return showModalBottomSheet<MaterialItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _MaterialPicker(),
  );
}

class _MaterialPicker extends StatefulWidget {
  const _MaterialPicker();

  @override
  State<_MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends State<_MaterialPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repository = context.read<WmsRepository>();
    final warehouseId = context.read<WarehouseController>().selectedId;
    final height = MediaQuery.of(context).size.height * 0.8;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar material pelo código ou nome :3',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: AsyncView<List<MaterialItem>>(
              // Puxa os materiais do galpão selecionado via API GET /api/materials (✿◠‿◠)
              load: () => repository.materials(warehouseId: warehouseId),
              builder: (context, items) {
                // Filtra instantaneamente pelo que o usuário digitou no campo de texto :3
                final visible = items
                    .where((e) => '${e.code} ${e.description}'.toLowerCase().contains(_query))
                    .toList();
                if (visible.isEmpty) {
                  return const EmptyState(message: 'Nenhum material encontrado com esse nome ;-;');
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return ListTile(
                      leading: MaterialThumb(item: item, size: 42),
                      title: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.code),
                      trailing: Text(
                        formatQuantity(item.quantity),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Tocou no item? Retorna ele para quem chamou e fecha a gaveta! ヽ(>∀<☆)ノ
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
