// ============================================================================
// ★ JANELINHAS E AVISOS DO SISTEMA (DIALOGS.DART) ★
// Aqui temos as caixinhas de diálogo e alertas que conversam com o usuário:
// 1) showToast: os balõezinhos flutuantes com mensagens amigáveis :3
// 2) showServerDialog: a janelinha pra testar e trocar o endereço da API! (｡•̀ᴗ-)✧
// 3) ConfirmDialog: caixinha de "tem certeza?" antes de apagar algo ;-;
// ============================================================================

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'smart_connection_dialog.dart';

// Mostra aquele aviso flutuante fofinho na parte inferior da tela (✿◠‿◠)
void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.danger : AppColors.textPrimary,
      ),
    );
}

// Janelinha modal pra trocar o endereço da API e testar se o servidor tá vivo :3
Future<void> showServerDialog(BuildContext context) {
  return showSmartConnectionDialog(context);
}
