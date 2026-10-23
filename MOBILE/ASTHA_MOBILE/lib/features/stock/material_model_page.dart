import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/wms_models.dart';
import '../warehouse/view_3d_platform.dart';

String materialModelHtml(String origin, String filename, Uint8List bytes) {
  final base = Uri.parse(origin).origin;
  final ext = filename.split('.').last.toLowerCase();
  if (!['stl', 'obj', 'gltf', 'glb'].contains(ext)) {
    throw const FormatException('Formato 3D não suportado.');
  }
  final data = base64Encode(bytes);
  return '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' 'wasm-unsafe-eval' $base https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; style-src 'unsafe-inline'; connect-src blob: $base; img-src blob: data:; worker-src blob: $base;">
<style>html,body,#model{margin:0;width:100%;height:100%;overflow:hidden;background:#f5f7f9}#status{position:absolute;top:12px;left:12px;padding:8px;background:white;border-radius:8px;font:14px sans-serif;z-index:2}</style></head><body><div id="model"></div><div id="status">Carregando modelo 3D…</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/STLLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/OBJLoader.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script crossorigin="anonymous" src="$base/app/js/sistema-3d-viewer.js"></script>
<script>try{const bytes=Uint8Array.from(atob('$data'),c=>c.charCodeAt(0));const url=URL.createObjectURL(new Blob([bytes]));const viewer=new ASTHAViewer3D('model');viewer.loadModel(url,'$ext',()=>{document.getElementById('status').textContent='Arraste para girar · role para ampliar';URL.revokeObjectURL(url)},()=>{document.getElementById('status').textContent='Não foi possível carregar este modelo';URL.revokeObjectURL(url)});window.addEventListener('pagehide',()=>{viewer.dispose();URL.revokeObjectURL(url)});}catch(e){document.getElementById('status').textContent='Visualização 3D indisponível neste dispositivo';}</script></body></html>''';
}

class MaterialModelPage extends StatefulWidget {
  const MaterialModelPage({super.key, required this.code, required this.file});
  final String code;
  final MaterialFile file;
  @override
  State<MaterialModelPage> createState() => _MaterialModelPageState();
}

class _MaterialModelPageState extends State<MaterialModelPage> {
  late final api = context.read<ApiClient>();
  late Future<Uint8List> data = _load();
  Future<Uint8List> _load() => api.download(
    '/api/materials/${Uri.encodeComponent(widget.code)}/files/${widget.file.id}/data',
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Modelo 3D · ${widget.code}')),
    body: FutureBuilder<Uint8List>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: () => setState(() => data = _load()),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Warehouse3dEmbed(
          baseUrl: api.baseUrl,
          blueprint: const {},
          items: const [],
          html: materialModelHtml(
            api.baseUrl,
            widget.file.filename,
            snapshot.data!,
          ),
        );
      },
    ),
  );
}
