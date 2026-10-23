// ============================================================================
// ★ ESTRUTURA DE COMPONENTES E KITS (COMPONENTS_PAGE.DART) ★
// Mostra a árvore de materiais (BOM - Bill of Materials):
// 1) Componentes compostos e kits de montagem industrial :3
// 2) Quais peças e materiais brutos formam cada produto final (✿◠‿◠)
// 3) Quantidades exatas necessárias de cada item no galpão! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../widgets/async_view.dart';

// Tela que exibe a lista de componentes e kits cadastrados no estoque :3
class ComponentsPage extends StatelessWidget {
  const ComponentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<WmsRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Componentes')),
      body: AsyncView<List<ComponentItem>>(
        // Chama a API GET /api/components para buscar as fórmulas de kits :3
        load: repository.components,
        builder: (context, components) {
          if (components.isEmpty) return const EmptyState(message: 'Nenhum componente cadastrado ;-;');
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: components.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ComponentTile(component: components[index]),
          );
        },
      ),
    );
  }
}

// Cartão sanfonado que expande para mostrar as peças individuais do kit :3
class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.component});

  final ComponentItem component;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.account_tree_outlined, color: AppColors.textSecondary),
        title: Text(component.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          (component.description == null || component.description!.isEmpty)
              ? '${component.parts.length} item(ns) :3'
              : component.description!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          if (component.parts.isEmpty)
            const ListTile(title: Text('Sem materiais vinculados ;-;'))
          else
            for (final part in component.parts)
              ListTile(
                dense: true,
                title: Text(part.code),
                trailing: Text(
                  '× ${formatQuantity(part.quantity)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
        ],
      ),
    );
  }
}
