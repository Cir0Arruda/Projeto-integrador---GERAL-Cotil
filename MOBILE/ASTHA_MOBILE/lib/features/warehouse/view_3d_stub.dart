// ============================================================================
// ★ VERSÃO STUB DO VISUALIZADOR 3D (VIEW_3D_STUB.DART) ★
// Serve como fallback seguro caso o aplicativo esteja rodando em uma
// plataforma sem suporte a Web ou WebView (ex: terminal ou testes de unidade) :3
// Assim o código compila perfeitamente sem dar tela vermelha de erro! (✿◠‿◠)
// ============================================================================

import 'package:flutter/material.dart';

// Widget neutro que apenas avisa se a plataforma não tiver motor 3D compatível :3
class Warehouse3dEmbed extends StatelessWidget {
  const Warehouse3dEmbed({
    super.key,
    required this.baseUrl,
    required this.blueprint,
    required this.items,
    this.floor = 0,
    this.warehouseName,
    this.url,
    this.html,
    this.onShelfSelected,
  });

  final String baseUrl;
  final Map<String, dynamic> blueprint;
  final List<Map<String, dynamic>> items;
  final int floor;
  final String? warehouseName;
  final String? url;
  final String? html;
  final ValueChanged<String>? onShelfSelected;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Visualizador 3D não suportado nesta plataforma ;-;'),
    );
  }
}
