import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/name_color_preset.dart';

/// CustomPainter для отрисовки вертикальной полосы цитирования
/// с различными стилями:
/// - solid (одноцветная)
/// - dualColor (двухцветная / градиентная)
/// - candyCane (трёхцветная диагональная полоса "карамельная палочка")
/// - segmented (пунктирная / сегментированная)
class ReplyStripPainter extends CustomPainter {
  final NameColorPreset preset;
  final ReplyStripStyle style;
  final double borderRadius;

  const ReplyStripPainter({
    required this.preset,
    required this.style,
    this.borderRadius = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    canvas.save();
    canvas.clipRRect(rrect);

    switch (style) {
      case ReplyStripStyle.solid:
        _paintSolid(canvas, rect);
        break;
      case ReplyStripStyle.dualColor:
        _paintDualColor(canvas, rect);
        break;
      case ReplyStripStyle.candyCane:
        _paintCandyCane(canvas, rect);
        break;
      case ReplyStripStyle.segmented:
        _paintSegmented(canvas, rect);
        break;
    }

    canvas.restore();
  }

  void _paintSolid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = preset.primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
  }

  void _paintDualColor(Canvas canvas, Rect rect) {
    final gradient = LinearGradient(
      colors: [
        preset.primaryColor,
        preset.effectiveSecondary,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
  }

  void _paintCandyCane(Canvas canvas, Rect rect) {
    final colors = [
      preset.primaryColor,
      preset.effectiveSecondary,
      preset.effectiveTertiary,
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-math.pi / 4); // 45 градусов диагональ

    const stripeWidth = 4.5; // Ширина каждой из 3 повторяющихся цветных полос
    final diagonalSpan = rect.height + rect.width + 40.0;

    int colorIndex = 0;
    for (double y = -diagonalSpan; y < diagonalSpan; y += stripeWidth) {
      paint.color = colors[colorIndex % colors.length];
      canvas.drawRect(
        Rect.fromLTWH(-diagonalSpan, y, diagonalSpan * 2, stripeWidth),
        paint,
      );
      colorIndex++;
    }

    canvas.restore();
  }

  void _paintSegmented(Canvas canvas, Rect rect) {
    final c1 = preset.primaryColor;
    final c2 = preset.effectiveSecondary;

    const gap = 3.0;
    const minSegHeight = 6.0;

    double availableHeight = rect.height;
    int numSegments = math.max(2, (availableHeight / (minSegHeight + gap)).floor());
    double segHeight = (availableHeight - (numSegments - 1) * gap) / numSegments;

    for (int i = 0; i < numSegments; i++) {
      final segTop = rect.top + i * (segHeight + gap);
      final segRect = Rect.fromLTWH(rect.left, segTop, rect.width, segHeight);
      final segRRect = RRect.fromRectAndRadius(segRect, const Radius.circular(1.5));

      final paint = Paint()
        ..color = (i % 2 == 0) ? c1 : c2
        ..style = PaintingStyle.fill;

      canvas.drawRRect(segRRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ReplyStripPainter oldDelegate) {
    return oldDelegate.preset.id != preset.id ||
        oldDelegate.style != style ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// Виджет полоски ответа
class ReplyStripWidget extends StatelessWidget {
  final NameColorPreset preset;
  final ReplyStripStyle style;
  final double width;
  final double height;
  final double borderRadius;

  const ReplyStripWidget({
    Key? key,
    required this.preset,
    required this.style,
    this.width = 3.5,
    this.height = double.infinity,
    this.borderRadius = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: ReplyStripPainter(
          preset: preset,
          style: style,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
