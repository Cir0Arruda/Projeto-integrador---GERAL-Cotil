// ============================================================================
// ★ EXPORTADOR CONDICIONAL DE PLATAFORMA PARA O 3D (VIEW_3D_PLATFORM.DART) ★
// Decide sozinho qual implementação de 3D usar:
// - No Celular (Android / iOS): Usa o WebView nativo (view_3d_io.dart) :3
// - Na Web: Usa o iframe HTML nativo do navegador (view_3d_web.dart) (✿◠‿◠)
// - Em outros ambientes: Usa a versão stub neutra (view_3d_stub.dart) (*¯︶¯*)
// ============================================================================

export 'view_3d_stub.dart'
    if (dart.library.js_interop) 'view_3d_web.dart'
    if (dart.library.io) 'view_3d_io.dart';
