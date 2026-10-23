// ============================================================================
// ★ MÓDULO PESSOAL DO USUÁRIO (PERSONAL_SHELL.DART) ★
// É o cantinho pessoal do usuário no RAVEN ASTHA! (✿◠‿◠)
// Permite organizar seus próprios espaços, objetos, pertences e compromissos!
// 1) Busca os espaços da pessoa na API: GET /api/personal/spaces :3
// 2) Possui 5 abas completas: Resumo, Espaços, Objetos, Pertences e Agenda (｡•̀ᴗ-)✧
// 3) Suporta adicionar coisas novas chamando as rotas da API em tempo real! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/personal_models.dart';
import '../../repositories/personal_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/connection_status_badge.dart';
import '../profile/profile_page.dart';
import 'personal_agenda_view.dart';
import 'personal_belongings_view.dart';
import 'personal_objects_view.dart';
import 'personal_spaces_view.dart';
import 'personal_summary_view.dart';

// A concha (Shell) que envolve todas as 5 telas do modo pessoal :3
class PersonalShell extends StatefulWidget {
  const PersonalShell({super.key});

  @override
  State<PersonalShell> createState() => _PersonalShellState();
}

class _PersonalShellState extends State<PersonalShell> {
  int _currentIndex = 0;
  List<PersonalSpace> _spaces = [];
  int? _currentSpaceId;
  String? _focusObjectId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<PersonalRepository>();
    try {
      final list = await repo.spaces();
      if (mounted) {
        setState(() {
          _spaces = list;
          final active = list.where((s) => !s.archived).toList();
          if (_currentSpaceId == null ||
              !active.any((s) => s.id == _currentSpaceId)) {
            _currentSpaceId = active.isNotEmpty ? active.first.id : null;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToSpace(int spaceId, String objectId) {
    setState(() {
      _currentIndex = 0;
      _currentSpaceId = spaceId;
      _focusObjectId = objectId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final activeSpaces = _spaces.where((s) => !s.archived).toList();
    final currentSpace = activeSpaces
        .where((s) => s.id == _currentSpaceId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ASTHA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brand),
                ),
                child: const Text(
                  'Pessoal',
                  style: TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          const Center(child: ConnectionStatusBadge(compact: true)),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Meu perfil',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'corp') {
                final change = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Entrar com conta corporativa'),
                    content: const Text(
                      'Seu espaço pessoal será preservado. Deseja sair para entrar com outra conta?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Sair e trocar de conta'),
                      ),
                    ],
                  ),
                );
                if (change == true) await session.signOut();
              } else if (val == 'reload') {
                await _loadSpaces();
              } else if (val == 'logout') {
                await session.signOut();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'corp',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 8),
                    Text('Conta corporativa'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reload',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Recarregar'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Sair', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadSpaces,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : IndexedStack(
              index: _currentIndex,
              children: [
                PersonalSpacesView(
                  spaces: _spaces,
                  currentSpace: currentSpace,
                  onSelectSpace: (id) => setState(() {
                    _currentSpaceId = id;
                    _focusObjectId = null;
                  }),
                  onReload: _loadSpaces,
                  initialSelectedObjectId: _focusObjectId,
                ),
                PersonalObjectsView(
                  spaces: _spaces,
                  onNavigateToSpace: _navigateToSpace,
                  onReload: _loadSpaces,
                ),
                PersonalBelongingsView(
                  spaces: _spaces,
                  onNavigateToSpace: _navigateToSpace,
                  onReload: _loadSpaces,
                ),
                PersonalAgendaView(spaces: _spaces, onReload: _loadSpaces),
                PersonalSummaryView(spaces: _spaces, onReload: _loadSpaces),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
            if (idx != 0) _focusObjectId = null;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.room_preferences_outlined),
            selectedIcon: Icon(Icons.room_preferences),
            label: 'Espaços',
          ),
          NavigationDestination(
            icon: Icon(Icons.weekend_outlined),
            selectedIcon: Icon(Icons.weekend),
            label: 'Móveis',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Pertences',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Resumo',
          ),
        ],
      ),
    );
  }
}
