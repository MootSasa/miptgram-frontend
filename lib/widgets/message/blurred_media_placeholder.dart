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
          // 1. Dark neutral base so parent bubble color NEVER bleeds through
          const ColoredBox(color: Color(0xFF181818)),

          // 2. Slightly overscaled and clipped blurred thumbnail with gentle blur
          ClipRect(
            child: Transform.scale(
              scale: 1.15,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Image.memory(
                  bytes,
                  fit: fit,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),

          // 3. Subtle darkening overlay for download button contrast
          Container(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ],
      );
    } else {
      content = Container(
        color: const Color(0xFF181818),
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
