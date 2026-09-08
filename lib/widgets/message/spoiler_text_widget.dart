import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/haptic_utils.dart';

/// Interactive Spoiler Widget with shimmer/noise particle animation.
///
/// Hides text or media content under an animated particle mask.
/// Tapping the spoiler reveals the underlying content with haptic feedback.
class SpoilerTextWidget extends StatefulWidget {
  final Widget child;
  final TextStyle? textStyle;
  final bool initialRevealed;
  final bool isMedia;
  final VoidCallback? onReveal;

  const SpoilerTextWidget({
    Key? key,
    required this.child,
    this.textStyle,
    this.initialRevealed = false,
    this.isMedia = false,
    this.onReveal,
  }) : super(key: key);

  SpoilerTextWidget.text({
    Key? key,
    required String text,
    TextStyle? style,
    bool initialRevealed = false,
    VoidCallback? onReveal,
  }) : this(
          key: key,
          child: Text(text, style: style),
          textStyle: style,
          initialRevealed: initialRevealed,
          isMedia: false,
          onReveal: onReveal,
        );

  @override
  State<SpoilerTextWidget> createState() => _SpoilerTextWidgetState();
}

class _SpoilerTextWidgetState extends State<SpoilerTextWidget>
    with SingleTickerProviderStateMixin {
  late bool _isRevealed;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.initialRevealed;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (!_isRevealed) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpoilerTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRevealed != oldWidget.initialRevealed &&
        widget.initialRevealed != _isRevealed) {
      setState(() {
        _isRevealed = widget.initialRevealed;
        if (_isRevealed) {
          _controller.stop();
        } else {
          _controller.repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_isRevealed) return;
    HapticUtils.tap();
    setState(() {
      _isRevealed = true;
      _controller.stop();
    });
    widget.onReveal?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isRevealed) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final particleColor = widget.textStyle?.color ??
        (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: _reveal,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [
              // Hidden child
              Opacity(
                opacity: widget.isMedia ? 0.05 : 0.0,
                child: widget.child,
              ),

              // Animated particle/noise layer
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SpoilerParticlePainter(
                        animationValue: _controller.value,
                        color: particleColor,
                        isMedia: widget.isMedia,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws shimmering noise particles resembling Telegram's spoiler effect.
class _SpoilerParticlePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isMedia;

  _SpoilerParticlePainter({
    required this.animationValue,
    required this.color,
    required this.isMedia,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final basePaint = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(3),
      ),
      basePaint,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Density of particles
    final double step = isMedia ? 6.0 : 4.5;
    final int rows = (size.height / step).ceil();
    final int cols = (size.width / step).ceil();

    // Pseudo-random shimmering dots
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final double phase = (r * 13 + c * 7) / 100.0;
        final double shimmer = (math.sin((animationValue * 2 * math.pi) + phase * 6.28) + 1.0) / 2.0;

        // Skip some particles to create an airy particle dust
        if ((r + c) % 3 == 0 && shimmer < 0.3) continue;

        final double opacity = (0.25 + shimmer * 0.65).clamp(0.0, 1.0);
        dotPaint.color = color.withValues(alpha: opacity);

        final double jitterX = (math.sin(phase * 10 + animationValue * 4) * 1.2);
        final double jitterY = (math.cos(phase * 10 + animationValue * 4) * 1.2);

        final double x = c * step + 2.0 + jitterX;
        final double y = r * step + 2.0 + jitterY;

        final double radius = 1.0 + (shimmer * 0.7);
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpoilerParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
