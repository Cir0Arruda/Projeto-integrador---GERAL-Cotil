// ============================================================================
// ★ EMBUTIDOR 3D PARA DISPOSITIVOS MÓVEIS (VIEW_3D_IO.DART) ★
// Renderiza o mapa 3D completo do armazém usando um WebView ultra rápido
// e acelerado por hardware no celular (Android e iOS)! ヽ(>∀<☆)ノ
// 1) Gera o HTML do Three.js dinamicamente com toda a planta baixa :3
// 2) Conecta a ponte de comunicação bidirecional com o Flutter (｡•̀ᴗ-)✧
// 3) Se o usuário tocar numa prateleira no 3D, o Flutter abre os itens dela! (✿◠‿◠)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'warehouse_3d_template.dart';

// O widget que encapsula a cena 3D dentro do app Flutter mobile :3
class Warehouse3dEmbed extends StatefulWidget {
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

  // Endereço base do servidor (usado para resolver scripts e recursos) :3
  final String baseUrl;
  // Planta baixa do armazém desenhada pelo usuário (paredes, prateleiras, docas) (*¯︶¯*)
  final Map<String, dynamic> blueprint;
  // Lista de materiais armazenados no galpão para desenhar as caixas nos nichos! (✿◠‿◠)
  final List<Map<String, dynamic>> items;
  // Qual andar do armazém estamos visualizando agora (0 = térreo) :3
  final int floor;
  // Nome bonitinho do galpão para exibir no HUD superior :3
  final String? warehouseName;
  // URL alternativa caso use iframe externo :3
  final String? url;
  final String? html;
  // Função chamada quando o usuário toca em uma prateleira na tela 3D! ヽ(>∀<☆)ノ
  final ValueChanged<String>? onShelfSelected;

  @override
  State<Warehouse3dEmbed> createState() => _Warehouse3dEmbedState();
}

class _Warehouse3dEmbedState extends State<Warehouse3dEmbed> {
  late final WebViewController? _controller;

  // Monta o documento HTML completo com o Three.js, luzes, sombras e prateleiras :3
  String _renderHtml() {
    return widget.html ??
        buildWarehouse3dHtml(
          scriptBase: widget.baseUrl,
          blueprint: widget.blueprint,
          items: widget.items,
          floor: widget.floor,
          warehouseName: widget.warehouseName,
        );
  }

  @override
  void initState() {
    super.initState();
    if (![
      TargetPlatform.android,
      TargetPlatform.iOS,
    ].contains(defaultTargetPlatform)) {
      _controller = null;
      return;
    }
    // Inicializa o motor do WebView do celular com JavaScript e aceleração gráfica! (｡•̀ᴗ-)✧
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F7F9))
      // Canal de conversa mágica: o JavaScript manda mensagens pro Flutter quando clica! (o^▽^o)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          widget.onShelfSelected?.call(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            debugPrint(
              '[WebView 3D] Aviso de recurso: ${error.description} (TwT)',
            );
          },
        ),
      )
      // Carrega o HTML com o Three.js e nossa cena 3D completinha :3
      ..loadHtmlString(_renderHtml(), baseUrl: widget.baseUrl);
  }

  @override
  void didUpdateWidget(Warehouse3dEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o andar mudou ou os itens do estoque foram alterados, recarrega a cena 3D! (✿◠‿◠)
    if (oldWidget.html != widget.html ||
        oldWidget.floor != widget.floor ||
        oldWidget.blueprint != widget.blueprint ||
        oldWidget.items != widget.items ||
        oldWidget.baseUrl != widget.baseUrl) {
      _controller?.loadHtmlString(_renderHtml(), baseUrl: widget.baseUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Renderiza a janelinha do WebView nativo na tela do Flutter :3
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: Text(
          'Use o aplicativo Android ou Chrome/Edge para visualizar o modelo 3D.',
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }
}
