// ============================================================================
// ★ EMBLEMA INTELIGENTE DE STATUS DE CONEXÃO (CONNECTION_STATUS_BADGE.DART) ★
// Esse widget mostra se o app tá conseguindo conversar com a API em tempo real! (✿◠‿◠)
// - 🟢 Verdinho: Conectado e funcionando com latência (ex: 32ms) :3
// - 🟡 Amarelinho: Buscando ou reconectando automaticamente... (TwT)
// - 🔴 Vermelhinho: Inacessível / Outra rede (Toque para diagnosticar e conectar!) ;-;
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_service.dart';
import '../state/session_controller.dart';
import 'smart_connection_dialog.dart';

// O crachá visual que fica no topo da tela ou na barra do app (｡•̀ᴗ-)✧
class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({super.key, this.compact = false});

  // Se true, mostra só a bolinha e um texto bem curtinho :3
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final conn = session.connectionService;

    return AnimatedBuilder(
      animation: conn,
      builder: (context, _) {
        final status = conn.status;
        final latency = conn.latencyMs;

        Color dotColor;
        Color bgColor;
        Color textColor;
        String text;
        IconData icon;

        switch (status) {
          case ConnectionStateStatus.online:
            dotColor = const Color(0xFF10B981); // Verde esmeralda lindo :3
            bgColor = const Color(0xFFE6F4EA);
            textColor = const Color(0xFF137333);
            text = latency != null ? 'Online · ${latency}ms' : 'Conectado';
            icon = Icons.wifi;
            break;
          case ConnectionStateStatus.checking:
            dotColor = const Color(0xFFF59E0B); // Amarelinho alerta (TwT)
            bgColor = const Color(0xFFFEF3C7);
            textColor = const Color(0xFFB45309);
            text = 'Buscando rede...';
            icon = Icons.sync;
            break;
          case ConnectionStateStatus.offline:
            dotColor = const Color(0xFFEF4444); // Vermelhinho socorro ;-;
            bgColor = const Color(0xFFFEE2E2);
            textColor = const Color(0xFFB91C1C);
            text = compact ? 'Sem conexão' : 'Sem conexão · Outra rede?';
            icon = Icons.wifi_off_rounded;
            break;
        }

        return InkWell(
          onTap: () => showSmartConnectionDialog(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: dotColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bolinha pulsante de status :3
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (!compact) ...[
                  Icon(icon, size: 14, color: textColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
