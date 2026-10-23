// ============================================================================
// ★ CABEÇALHO SUPERIOR DO APP (ASTHA_HEADER.DART) ★
// Esse é o topo bonitão que aparece nas nossas telas! (✿◠‿◠)
// Mostra a logo da RAVEN ASTHA, o nome da organização, o plano (Free/Pro),
// o seletor de galpão e o avatarzinho fofo do usuário pra abrir o perfil :3
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../features/profile/profile_page.dart';
import '../models/account_models.dart';
import '../repositories/account_repository.dart';
import '../state/session_controller.dart';
import 'connection_status_badge.dart';
import 'user_avatar.dart';
import 'warehouse_selector.dart';

// O widget da barra superior! Implementa PreferredSizeWidget pra funcionar como AppBar :3
class AsthaHeader extends StatelessWidget implements PreferredSizeWidget {
  const AsthaHeader({
    super.key,
    this.showWarehouseSelector = false,
    this.actions,
  });

  // Diz se a gente quer mostrar a caixinha de escolher galpão/armazém aqui em cima (｡•̀ᴗ-)✧
  final bool showWarehouseSelector;
  // Botõezinhos extras que você queira colocar na direita :3
  final List<Widget>? actions;

  // A alturinha perfeita da barra superior (60 pixels) (o^▽^o)
  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    // Escuta a sessão pra saber quem é o usuário logado no momento! (づ｡◕‿‿◕｡)づ
    final session = context.watch<SessionController>();
    final user = session.user;
    // Pega o repositório pra consultar dados da organização na API
    final accountRepo = context.read<AccountRepository>();

    return SafeArea(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            // Lado esquerdo: Logo + Nome da Empresa + Selinho do Plano (TwT)
            Expanded(
              child: FutureBuilder<Organization>(
                // Busca os dados da organização chamando a API do backend! :3
                future: accountRepo.organization(),
                builder: (context, snapshot) {
                  final org = snapshot.data;
                  final orgName = org?.name ?? user?.orgName ?? 'RAVEN ASTHA';
                  final plan = org?.planLabel ?? 'Free';
                  final logoUrl = org?.logoUrl;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logoUrl != null && logoUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(logoUrl.split(',').last),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _InitialMark(orgName: orgName),
                              )
                            : _InitialMark(orgName: orgName),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.brandLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                plan.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandText,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Seletor de armazém: permite trocar entre os galpões cadastrados no sistema (｡•̀ᴗ-)✧
            if (showWarehouseSelector) ...[
              const WarehouseSelector(),
              const SizedBox(width: 8),
            ],
            // Emblema compacto de status de conexão multi-rede :3
            const ConnectionStatusBadge(compact: true),
            const SizedBox(width: 8),
            // Ações extras que a tela que chamou o header quiser injetar :3
            if (actions != null) ...[
              ...actions!,
              const SizedBox(width: 8),
            ],
            // Avatar do usuário: quando clica nele, abre a tela de perfil do usuário! (✿◠‿◠)
            if (user != null)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
                  );
                },
                child: UserAvatar(
                  name: user.displayName,
                  avatarUrl: user.avatarUrl,
                  radius: 17,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InitialMark extends StatelessWidget {
  const _InitialMark({required this.orgName});

  final String orgName;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        final initial = orgName.isNotEmpty ? orgName[0].toUpperCase() : 'R';
        return Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}
