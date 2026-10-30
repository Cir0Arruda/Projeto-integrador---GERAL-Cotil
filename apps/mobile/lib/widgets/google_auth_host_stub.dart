// ============================================================================
// ★ HOSPEDEIRO GOOGLE AUTH STUB (GOOGLE_AUTH_HOST_STUB.DART) ★
// Stub neutro que garante compilação limpa em testes sem dependências de tela :3
// ============================================================================

import 'package:flutter/material.dart';

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
