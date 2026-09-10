import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../utils/haptic_utils.dart';

/// Lightweight particle for Telegram-style spoiler noise and shimmering dust.
class SpoilerParticle {
  double x;
  double y;
  double vx;
  double vy;
  double alpha;
  double targetAlpha;
  double size;

  SpoilerParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.alpha,
    required this.targetAlpha,
    required this.size,
  });

  static final math.Random _random = math.Random();

  static SpoilerParticle create(double width, double height, {bool isMedia = false}) {
    final speed = isMedia ? 0.85 : 0.6;
    final angle = _random.nextDouble() * 2 * math.pi;
    final vMag = 0.2 + _random.nextDouble() * speed;
    return SpoilerParticle(
      x: _random.nextDouble() * (width > 0 ? width : 20.0),
      y: _random.nextDouble() * (height > 0 ? height : 20.0),
      vx: math.cos(angle) * vMag,
      vy: math.sin(angle) * vMag,
      alpha: 0.2 + _random.nextDouble() * 0.7,
      targetAlpha: 0.2 + _random.nextDouble() * 0.7,
      size: 1.5 + _random.nextDouble() * (isMedia ? 1.5 : 0.9),
    );
  }

  void update(double width, double height) {
    x += vx;
    y += vy;

    if (width > 0) {
      if (x < 0) x += width;
      if (x > width) x -= width;
    }

    if (height > 0) {
      if (y < 0) y += height;
      if (y > height) y -= height;
    }

    // Smooth random twinkle
    if ((alpha - targetAlpha).abs() < 0.05) {
      targetAlpha = 0.2 + _random.nextDouble() * 0.75;
    } else {
      alpha += (targetAlpha - alpha) * 0.08;
    }
  }

  void explode(double factor) {
    x += vx * factor;
    y += vy * factor;
  }
}

/// Interactive Spoiler Widget with Telegram-style shimmer particle animation.
///
/// Hides text or media content under an animated particle mask.
/// Tapping the spoiler reveals the underlying content with haptic feedback
/// and a smooth particle dispersion animation.
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
          child: Text(
            text,
            style: style,
          ),
          textStyle: style,
          initialRevealed: initialRevealed,
          isMedia: false,
          onReveal: onReveal,
        );

  @override
  State<SpoilerTextWidget> createState() => _SpoilerTextWidgetState();
}

class _SpoilerTextWidgetState extends State<SpoilerTextWidget>
    with TickerProviderStateMixin {
  late bool _isFullyRevealed;
  bool _isRevealing = false;

  late AnimationController _loopController;
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;

  final List<SpoilerParticle> _particles = [];
  double _lastWidth = 0;
  double _lastHeight = 0;

  @override
  void initState() {
    super.initState();
    _isFullyRevealed = widget.initialRevealed;

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() {
              _isFullyRevealed = true;
              _isRevealing = false;
              _loopController.stop();
            });
          }
        }
      });

    if (!_isFullyRevealed) {
      _loopController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpoilerTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRevealed != oldWidget.initialRevealed &&
        widget.initialRevealed != _isFullyRevealed) {
      setState(() {
        _isFullyRevealed = widget.initialRevealed;
        _isRevealing = false;
        if (_isFullyRevealed) {
          _loopController.stop();
        } else {
          _loopController.repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _reveal() {
    if (_isFullyRevealed || _isRevealing) return;
    HapticUtils.tap();
    setState(() {
      _isRevealing = true;
    });
    _revealController.forward(from: 0.0);
    widget.onReveal?.call();
  }

  void _ensureParticles(double width, double height) {
    if (width <= 0 || height <= 0) return;
    if ((width - _lastWidth).abs() < 2 && (height - _lastHeight).abs() < 2 && _particles.isNotEmpty) {
      return;
    }
    _lastWidth = width;
    _lastHeight = height;

    final targetCount = ((width * height) / (widget.isMedia ? 36.0 : 28.0)).clamp(16, 750).toInt();

    while (_particles.length < targetCount) {
      _particles.add(SpoilerParticle.create(width, height, isMedia: widget.isMedia));
    }
    if (_particles.length > targetCount) {
      _particles.removeRange(targetCount, _particles.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullyRevealed) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final particleColor = widget.textStyle?.color ??
        (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: _reveal,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: _isRevealing ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [
              // Hidden/Revealing child
              AnimatedBuilder(
                animation: _revealAnimation,
                builder: (context, child) {
                  final opacity = _isRevealing
                      ? _revealAnimation.value
                      : (widget.isMedia ? 0.05 : 0.0);
                  return Opacity(
                    opacity: opacity,
                    child: child,
                  );
                },
                child: widget.child,
              ),

              // Animated particle layer
              if (!_isFullyRevealed)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _ensureParticles(constraints.maxWidth, constraints.maxHeight);
                      return CustomPaint(
                        painter: _TelegramSpoilerParticlePainter(
                          particles: _particles,
                          color: particleColor,
                          isMedia: widget.isMedia,
                          revealAnimation: _isRevealing ? _revealAnimation : null,
                          repaint: _isRevealing ? _revealAnimation : _loopController,
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
///
/// Uses [Canvas.drawPoints] for maximum rendering performance, batching all particle
/// coordinates into GPU point primitives instead of hundreds of [Canvas.drawCircle] calls.
class _TelegramSpoilerParticlePainter extends CustomPainter {
  final List<SpoilerParticle> particles;
  final Color color;
  final bool isMedia;
  final Animation<double>? revealAnimation;

  _TelegramSpoilerParticlePainter({
    required this.particles,
    required this.color,
    required this.isMedia,
    this.revealAnimation,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || particles.isEmpty) return;

    final revealT = revealAnimation?.value ?? 0.0;
    final remainingOpacity = (1.0 - revealT).clamp(0.0, 1.0);
    if (remainingOpacity <= 0.0) return;

    // Tinted underlay mask so text characters underneath are obscured
    final underlayAlpha = (isMedia ? 0.25 : 0.20) * remainingOpacity;
    if (underlayAlpha > 0.01) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3)),
        Paint()
          ..color = color.withValues(alpha: underlayAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    final brightPoints = <Offset>[];
    final dimPoints = <Offset>[];

    final explosionFactor = 1.0 + revealT * 3.5;

    for (final p in particles) {
      if (revealT > 0) {
        p.explode(explosionFactor);
      } else {
        p.update(size.width, size.height);
      }

      final pt = Offset(p.x, p.y);
      if (p.alpha > 0.5) {
        brightPoints.add(pt);
      } else {
        dimPoints.add(pt);
      }
    }

    final dimAlpha = (0.45 * remainingOpacity).clamp(0.0, 1.0);
    if (dimPoints.isNotEmpty && dimAlpha > 0.01) {
      canvas.drawPoints(
        ui.PointMode.points,
        dimPoints,
        Paint()
          ..color = color.withValues(alpha: dimAlpha)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }

    final brightAlpha = (0.85 * remainingOpacity).clamp(0.0, 1.0);
    if (brightPoints.isNotEmpty && brightAlpha > 0.01) {
      canvas.drawPoints(
        ui.PointMode.points,
        brightPoints,
        Paint()
          ..color = color.withValues(alpha: brightAlpha)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TelegramSpoilerParticlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.revealAnimation != revealAnimation;
  }
}
