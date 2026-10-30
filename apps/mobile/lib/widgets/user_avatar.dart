// ============================================================================
// ★ AVATAR REDONDINHO DO USUÁRIO (USER_AVATAR.DART) ★
// Desenha a fotinho de perfil da pessoa cadastrada no sistema! (✿◠‿◠)
// Se a pessoa tiver foto salva no banco de dados, carrega em alta definição.
// Se não tiver fotinho, coloca as iniciais do nome com uma cor bem elegante :3
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';

// O avatar circular que aparece na barra superior e nos comentários :3
class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key, required this.name, this.avatarUrl, this.radius = 22, this.color});

  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? color;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _bytes;
  String? _source;

  static Uint8List? _decode(String? data) {
    if (data == null || !data.startsWith('data:image')) return null;
    final comma = data.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(data.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  ImageProvider? _imageProvider(String? url, Uint8List? bytes) {
    if (bytes != null) return MemoryImage(bytes);
    if (url == null || url.trim().isEmpty || url.startsWith('data:image')) return null;
    final resolved = url.startsWith('http') ? url : '${AppConfig.defaultServerUrl}$url';
    return NetworkImage(resolved);
  }

  @override
  Widget build(BuildContext context) {
    if (_source != widget.avatarUrl) {
      _source = widget.avatarUrl;
      _bytes = _decode(widget.avatarUrl);
    }
    final accent = widget.color ?? AppColors.brandDark;
    final bytes = _bytes;
    final provider = _imageProvider(widget.avatarUrl, bytes);
    final initial = widget.name.trim().isEmpty ? '?' : widget.name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: accent.withValues(alpha: 0.15),
      backgroundImage: provider,
      child: provider != null
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: widget.radius * 0.8,
              ),
            ),
    );
  }
}
