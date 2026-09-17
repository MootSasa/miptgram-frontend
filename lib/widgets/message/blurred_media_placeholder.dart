import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Renders a high-performance blurred preview placeholder for photos/videos
/// using the micro-thumbnail or a subtle animated gradient.
class BlurredMediaPlaceholder extends StatelessWidget {
  final String? thumbBase64;
  final double aspectRatio;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const BlurredMediaPlaceholder({
    Key? key,
    this.thumbBase64,
    this.aspectRatio = 1.0,
    this.fit = BoxFit.cover,
    this.borderRadius,
  }) : super(key: key);

  Uint8List? _decodeBytes() {
    if (thumbBase64 == null || thumbBase64!.isEmpty) return null;
    try {
      String raw = thumbBase64!;
      if (raw.contains(',')) {
        raw = raw.split(',').last;
      }
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBytes();

    Widget content;
    if (bytes != null && bytes.isNotEmpty) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Image.memory(
              bytes,
              fit: fit,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.15),
          ),
        ],
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade800,
              Colors.grey.shade900,
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: Colors.white24,
            size: 32,
          ),
        ),
      );
    }

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
