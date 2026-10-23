// ============================================================================
// ★ MINIATURA DE FOTO DO MATERIAL (MATERIAL_THUMB.DART) ★
// Exibe a fotinho de cada peça ou material do estoque com muito estilo! (✿◠‿◠)
// Se o material tiver foto em Base64 ou URL vinda da API, decodifica e mostra.
// Se não tiver fotinho, desenha um ícone elegante pra não ficar vazio :3
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/wms_models.dart';

// O quadradinho com a imagem do material (｡•̀ᴗ-)✧
class MaterialThumb extends StatefulWidget {
  const MaterialThumb({
    super.key,
    required this.item,
    this.size = 48,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  // O objeto do material (vindo da API!) que contém os dados da foto :3
  final MaterialItem item;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  @override
  State<MaterialThumb> createState() => _MaterialThumbState();
}

class _MaterialThumbState extends State<MaterialThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode(widget.item);
  }

  @override
  void didUpdateWidget(covariant MaterialThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageData != widget.item.imageData ||
        oldWidget.item.imageUrl != widget.item.imageUrl) {
      _bytes = _decode(widget.item);
    }
  }

  static Uint8List? _decode(MaterialItem item) {
    try {
      final raw = item.imageData ??
          ((item.imageUrl != null && item.imageUrl!.startsWith('data:image/'))
              ? item.imageUrl
              : null);
      if (raw == null || raw.isEmpty) return null;
      final comma = raw.indexOf(',');
      var payload = comma >= 0 ? raw.substring(comma + 1) : raw;
      payload = payload.replaceAll(RegExp(r'\s+'), '');
      if (payload.isEmpty) return null;
      final remainder = payload.length % 4;
      if (remainder != 0) {
        payload = payload.padRight(payload.length + (4 - remainder), '=');
      }
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: _image(context),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    final url = _resolve(context, widget.item.imageUrl);
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  String? _resolve(BuildContext context, String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('data:image/')) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('/')) {
      final base = context.read<ApiClient>().baseUrl;
      return '$base$trimmed';
    }
    return null;
  }

  Widget _placeholder() => Container(
        color: AppColors.background,
        child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
      );
}
