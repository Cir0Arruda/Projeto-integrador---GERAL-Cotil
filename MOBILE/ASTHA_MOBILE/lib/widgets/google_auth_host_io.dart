// ============================================================================
// ★ HOSPEDEIRO GOOGLE AUTH PARA MOBILE/IO (GOOGLE_AUTH_HOST_IO.DART) ★
// No celular nativo, a autenticação Google usa o fluxo visual customizado
// com diálogo ou login nativo :3
// ============================================================================

import 'package:flutter/material.dart';

// Componente visual nativo para mobile :3
class GoogleAuthHostPlatform extends StatelessWidget {
  const GoogleAuthHostPlatform({
    super.key,
    required this.clientId,
    required this.nonce,
    required this.onCredential,
  });

  final String clientId;
  final String nonce;
  final ValueChanged<String> onCredential;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
