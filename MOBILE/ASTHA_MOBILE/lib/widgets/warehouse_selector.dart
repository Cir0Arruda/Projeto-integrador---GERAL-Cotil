// ============================================================================
// ★ SELETOR DE GALPÃO / ARMAZÉM (WAREHOUSE_SELECTOR.DART) ★
// Permite que o operador troque de galpão num piscar de olhos! (✿◠‿◠)
// Conecta com o WarehouseController pra pegar a lista de galpões vindos da API
// e altera o galpão ativo em todas as telas simultaneamente! (｡•̀ᴗ-)✧
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/warehouse_controller.dart';

// Botãozinho no topo que abre o menu para escolher o armazém :3
class WarehouseSelector extends StatelessWidget {
  const WarehouseSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuta o controlador de armazéns (que buscou os dados na API) :3
    final controller = context.watch<WarehouseController>();
    final selected = controller.selected;
    if (selected == null) return const SizedBox.shrink();

    // Menu suspenso (dropdown bonitinho) com os galpões disponíveis (o^▽^o)
    return PopupMenuButton<int>(
      tooltip: 'Trocar armazém',
      enabled: controller.tabs.length > 1,
      // Ao tocar em um galpão, avisa o controlador pra mudar tudo! ヽ(>∀<☆)ノ
      onSelected: (id) => controller.select(controller.tabs.firstWhere((tab) => tab.id == id)),
      itemBuilder: (_) => [
        for (final tab in controller.tabs)
          PopupMenuItem(
            value: tab.id,
            child: Row(
              children: [
                Icon(
                  tab.id == selected.id ? Icons.check_circle : Icons.warehouse_outlined,
                  size: 18,
                  color: tab.id == selected.id ? AppColors.brand : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(tab.name)),
              ],
            ),
          ),
      ],
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warehouse_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                selected.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (controller.tabs.length > 1)
              const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
