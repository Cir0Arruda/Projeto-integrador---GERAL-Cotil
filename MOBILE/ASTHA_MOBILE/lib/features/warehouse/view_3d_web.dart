// ============================================================================
// ★ EMBUTIDOR 3D PARA NAVEGADORES WEB (VIEW_3D_WEB.DART) ★
// Se você abrir o app no Chrome ou Edge, ele cria um iframe HTML5 nativo
// com srcdoc ultra veloz e injeta o Three.js com aceleração WebGL! ヽ(>∀<☆)ノ
// 1) Registra uma fábrica de visão no PlatformViewRegistry da Web :3
// 2) Ouve eventos postMessage da cena 3D pra avisar quando uma prateleira for clicada! (｡•̀ᴗ-)✧
// 3) Garante que o iframe ocupe 100% da área sem bordas chatas (✿◠‿◠)
// ============================================================================

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'warehouse_3d_template.dart';

// Componente web que embute o visualizador 3D do armazém usando um iframe nativo com srcdoc (✿◠‿◠)
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

  // Endereço base do servidor :3
  final String baseUrl;
  // Planta baixa do armazém com paredes, docas e estantes (*¯︶¯*)
  final Map<String, dynamic> blueprint;
  // Itens estocados em cada posição da prateleira :3
  final List<Map<String, dynamic>> items;
  // Andar atual (0 = térreo) :3
  final int floor;
  // Nome do galpão pra colocar no letreiro :3
  final String? warehouseName;
  // URL alternativa caso use fonte externa :3
  final String? url;
  final String? html;
  // Callback disparado quando o usuário clica numa estante! (｡•̀ᴗ-)✧
  final ValueChanged<String>? onShelfSelected;

  @override
  State<Warehouse3dEmbed> createState() => _Warehouse3dEmbedState();
}

class _Warehouse3dEmbedState extends State<Warehouse3dEmbed> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  JSFunction? _listener;

  // Gera o HTML do visualizador 3D com os scripts e o Three.js embutidos! :3
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

  // Atualiza o documento HTML dentro do iframe web de forma instantânea :3
  void _applyContent(web.HTMLIFrameElement iframe) {
    final html = _renderHtml();
    iframe.srcdoc = html.toJS;
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'w3d-view-${DateTime.now().microsecondsSinceEpoch}';
    // Registra a fábrica no ecossistema web do Flutter (✿◠‿◠)
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block';
      _applyContent(iframe);
      _iframe = iframe;
      return iframe;
    });

    // Ouve mensagens postMessage disparadas do JavaScript de dentro do iframe! (｡•̀ᴗ-)✧
    void onMessage(web.Event event) {
      if (event.isA<web.MessageEvent>()) {
        final msg = event as web.MessageEvent;
        if (msg.source != _iframe?.contentWindow) return;
        if (msg.data != null) {
          final raw = msg.data.dartify();
          if (raw is Map &&
              raw['type'] == 'SHELF_SELECTED' &&
              raw['shelfId'] != null) {
            widget.onShelfSelected?.call(raw['shelfId'].toString());
          }
        }
      }
    }

    _listener = onMessage.toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void didUpdateWidget(Warehouse3dEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se mudou de andar ou atualizaram os itens, recarrega o iframe :3
    if (oldWidget.html != widget.html ||
        oldWidget.floor != widget.floor ||
        oldWidget.blueprint != widget.blueprint ||
        oldWidget.items != widget.items ||
        oldWidget.baseUrl != widget.baseUrl) {
      if (_iframe != null) {
        _applyContent(_iframe!);
      }
    }
  }

  @override
  void dispose() {
    // Remove o ouvinte de mensagens pra não vazar memória! (*¯︶¯*)
    if (_listener != null) {
      web.window.removeEventListener('message', _listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: HtmlElementView(viewType: _viewType));
  }
}
