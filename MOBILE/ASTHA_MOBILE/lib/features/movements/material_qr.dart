import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

String materialQrPayload(String code, String org) =>
    jsonEncode({'kind': 'astha-material', 'v': 1, 'code': code, 'org': org});
String materialCodeFromQr(String raw, String org) {
  if (raw.length > 2048) throw const FormatException('QR Code inválido.');
  final data = jsonDecode(raw);
  if (data is! Map ||
      data['kind'] != 'astha-material' ||
      data['v'] != 1 ||
      data['org'] != org ||
      data['code'] is! String) {
    throw const FormatException('Este QR Code não pertence à sua organização.');
  }
  final code = data['code'] as String;
  if (code.isEmpty ||
      code.length > 100 ||
      RegExp(r'[\x00-\x1f]').hasMatch(code)) {
    throw const FormatException('Código de material inválido.');
  }
  return code;
}

class MaterialQrScanner extends StatefulWidget {
  const MaterialQrScanner({super.key, required this.org});
  final String org;
  @override
  State<MaterialQrScanner> createState() => _MaterialQrScannerState();
}

class _MaterialQrScannerState extends State<MaterialQrScanner> {
  bool done = false;
  String? error;
  final input = TextEditingController();
  void accept(String raw) {
    if (done) return;
    try {
      final code = materialCodeFromQr(raw, widget.org);
      done = true;
      Navigator.pop(context, code);
    } catch (_) {
      setState(() => error = 'QR inválido ou pertencente a outra organização.');
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ler QR Code do material')),
    body: Column(
      children: [
        Expanded(
          child:
              !kIsWeb &&
                  ![
                    TargetPlatform.android,
                    TargetPlatform.iOS,
                    TargetPlatform.macOS,
                  ].contains(defaultTargetPlatform)
              ? const Center(
                  child: Text(
                    'Cole o conteúdo do QR abaixo ou use a câmera no aplicativo Android ou navegador.',
                  ),
                )
              : MobileScanner(
                  onDetect: (capture) {
                    final raw = capture.barcodes.firstOrNull?.rawValue;
                    if (raw != null) accept(raw);
                  },
                  errorBuilder: (c, e) => const Center(
                    child: Text(
                      'Câmera indisponível. Autorize o acesso ou cole o conteúdo do QR abaixo.',
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              TextField(
                controller: input,
                decoration: const InputDecoration(
                  labelText: 'Colar conteúdo do QR Code',
                ),
              ),
              TextButton(
                onPressed: () => accept(input.text.trim()),
                child: const Text('Usar código colado'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
