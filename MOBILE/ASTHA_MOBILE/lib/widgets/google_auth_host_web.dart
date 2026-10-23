// ============================================================================
// ★ BOTÃO NATIVO GOOGLE IDENTITY SERVICES NA WEB (GOOGLE_AUTH_HOST_WEB.DART) ★
// Na Web, renderiza o botão oficial do Google Sign-In usando a biblioteca
// Google Identity Services (GIS) via interop JS nativo! ヽ(>∀<☆)ノ
// 1) Inicializa o SDK do Google com o client_id e nonce :3
// 2) Renderiza o botão com design oficial do Google (✿◠‿◠)
// 3) Captura a resposta e devolve a credencial pro Flutter! (｡•̀ᴗ-)✧
// ============================================================================

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('google')
external JSAny? get _googleGis;

@JS('google.accounts.id.initialize')
external void _initializeGis(JSAny options);

@JS('google.accounts.id.renderButton')
external void _renderGisButton(web.HTMLElement parent, JSAny options);

// Componente que injeta o botão oficial do Google no navegador web :3
class GoogleAuthHostPlatform extends StatefulWidget {
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
  State<GoogleAuthHostPlatform> createState() => _GoogleAuthHostPlatformState();
}

class _GoogleAuthHostPlatformState extends State<GoogleAuthHostPlatform> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'google-btn-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final host = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '44px'
        ..style.display = 'flex'
        ..style.justifyContent = 'center'
        ..style.alignItems = 'center';

      void tryRender([int attempt = 0]) {
        try {
          if (_googleGis == null) {
            if (attempt < 40) {
              web.window.setTimeout((() => tryRender(attempt + 1)).toJS, 100.toJS);
            }
            return;
          }

          void onCallback(JSObject response) {
            final dartMap = response.dartify();
            if (dartMap is Map && dartMap['credential'] != null) {
              widget.onCredential(dartMap['credential'].toString());
            }
          }

          final initOptions = <String, JSAny?>{
            'client_id': widget.clientId.toJS,
            'nonce': widget.nonce.toJS,
            'auto_select': false.toJS,
            'callback': onCallback.toJS,
          }.jsify()!;

          final renderOptions = <String, JSAny?>{
            'type': 'standard'.toJS,
            'theme': 'outline'.toJS,
            'size': 'large'.toJS,
            'text': 'continue_with'.toJS,
            'shape': 'pill'.toJS,
            'locale': 'pt-BR'.toJS,
            'width': 260.toJS,
          }.jsify()!;

          _initializeGis(initOptions);
          _renderGisButton(host, renderOptions);
        } catch (_) {}
      }

      web.window.setTimeout((() => tryRender(0)).toJS, 50.toJS);
      return host;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
