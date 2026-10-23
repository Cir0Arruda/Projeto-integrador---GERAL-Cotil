// ============================================================================
// ★ HOSPEDEIRO DE AUTENTICAÇÃO COM CONTA GOOGLE (GOOGLE_AUTH_HOST.DART) ★
// Permite entrar no aplicativo direto com a sua conta Google:
// 1) Pega o token JWT oficial emitido pelos servidores do Google :3
// 2) Envia o token assinado para validação segura na API do RAVEN ASTHA (✿◠‿◠)
// 3) Cria ou conecta a conta de usuário na velocidade da luz! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';

import 'google_auth_host_stub.dart'
    if (dart.library.js_interop) 'google_auth_host_web.dart'
    if (dart.library.io) 'google_auth_host_io.dart';

// O guardião que invoca a implementação certa do botão do Google dependendo da plataforma :3
class GoogleAuthHost extends StatelessWidget {
  const GoogleAuthHost({
    super.key,
    required this.clientId,
    required this.nonce,
    required this.onCredential,
  });

  // Client ID oficial gerado no console do Google Cloud :3
  final String clientId;
  // Código de segurança (nonce) pra evitar ataque de repetição (｡•̀ᴗ-)✧
  final String nonce;
  // Callback disparado quando o Google entrega a credencial com sucesso! (✿◠‿◠)
  final ValueChanged<String> onCredential;

  @override
  Widget build(BuildContext context) {
    return GoogleAuthHostPlatform(
      clientId: clientId,
      nonce: nonce,
      onCredential: onCredential,
    );
  }
}
