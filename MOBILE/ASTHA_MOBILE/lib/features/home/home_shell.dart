// ============================================================================
// ★ ESTRUTURA PRINCIPAL DE NAVEGAÇÃO (HOME_SHELL.DART) ★
// É a casa principal do app corporativo! (✿◠‿◠)
// 1) Tem a barra inferior com os 5 botões: Launchpad, Estoque, Movimentar, Manutenção e Mais :3
// 2) Conecta a barra superior (AsthaHeader) com a logo e o seletor de galpões (｡•̀ᴗ-)✧
// 3) Garante que o galpão seja carregado na API antes de exibir as telas! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/warehouse_controller.dart';
import '../../widgets/astha_header.dart';
import '../../widgets/async_view.dart';
import '../eam/eam_page.dart';
import '../launchpad/launchpad_page.dart';
import '../movements/movement_tab.dart';
import '../stock/stock_page.dart';
import 'more_page.dart';

// O esqueleto da tela inicial com a barra de navegação inferior :3
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _destinations = <({String title, IconData icon, IconData selected, bool needsWarehouse})>[
    (title: 'Launchpad', icon: Icons.dashboard_outlined, selected: Icons.dashboard, needsWarehouse: false),
    (title: 'Estoque', icon: Icons.inventory_2_outlined, selected: Icons.inventory_2, needsWarehouse: true),
    (title: 'Movimentar', icon: Icons.swap_vert_outlined, selected: Icons.swap_vert, needsWarehouse: true),
    (title: 'Manutenção', icon: Icons.build_outlined, selected: Icons.build, needsWarehouse: false),
    (title: 'Mais', icon: Icons.menu, selected: Icons.menu_open, needsWarehouse: false),
  ];

  final Set<int> _visited = {0};
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WarehouseController>().load();
    });
  }

  Widget _page(int index) => switch (index) {
        0 => const LaunchpadPage(),
        1 => const StockPage(),
        2 => const MovementTab(),
        3 => const EamPage(),
        _ => const MorePage(),
      };

  Widget _body(int index, WarehouseController warehouses) {
    if (!_destinations[index].needsWarehouse) return _page(index);
    if (warehouses.loading && warehouses.tabs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (warehouses.error != null) {
      return RefreshIndicator(
        onRefresh: warehouses.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 48),
            Text(warehouses.error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: warehouses.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (warehouses.selected == null) {
      return const EmptyState(
        message: 'Nenhum armazém cadastrado. Crie um pelo sistema web.',
        icon: Icons.warehouse_outlined,
      );
    }
    return KeyedSubtree(key: ValueKey(warehouses.selectedId), child: _page(index));
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = context.watch<WarehouseController>();
    final current = _destinations[_index];

    return Scaffold(
      appBar: AsthaHeader(
        showWarehouseSelector: current.needsWarehouse,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _visited.contains(i) ? _body(i, warehouses) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() {
          _index = value;
          _visited.add(value);
        }),
        destinations: [
          for (final item in _destinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selected),
              label: item.title,
            ),
        ],
      ),
    );
  }
}
