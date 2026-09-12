import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/video_note_playback_service.dart';

/// Draggable, Telegram-style floating circular video note overlay (PiP).
/// Displays in the corner when the actively playing video note scrolls out of view.
class FloatingVideoNoteOverlay extends StatefulWidget {
  const FloatingVideoNoteOverlay({Key? key}) : super(key: key);

  @override
  State<FloatingVideoNoteOverlay> createState() => _FloatingVideoNoteOverlayState();
}

class _FloatingVideoNoteOverlayState extends State<FloatingVideoNoteOverlay> {
  final VideoNotePlaybackService _service = VideoNotePlaybackService();
  static const double _kSize = 114.0;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isFloating || _service.activeController == null) {
      return const SizedBox.shrink();
    }

    final controller = _service.activeController!;
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final topPadding = mediaQuery.padding.top + 40.0;
    final bottomPadding = mediaQuery.padding.bottom + 80.0;

    // Default position: top right if not positioned yet
    Offset currentPos = _service.floatingPosition;
    if (currentPos.dx == 20 && currentPos.dy == 96) {
      currentPos = Offset(screenSize.width - _kSize - 16, topPadding + 10);
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    final double targetProgress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      fit: StackFit.loose,
      children: [
        Positioned(
          left: currentPos.dx.clamp(8.0, screenSize.width - _kSize - 8.0),
          top: currentPos.dy.clamp(topPadding, screenSize.height - _kSize - bottomPadding),
          child: GestureDetector(
            onPanUpdate: (details) {
              final newX = (currentPos.dx + details.delta.dx)
                  .clamp(8.0, screenSize.width - _kSize - 8.0);
              final newY = (currentPos.dy + details.delta.dy)
                  .clamp(topPadding, screenSize.height - _kSize - bottomPadding);
              _service.updateFloatingPosition(Offset(newX, newY));
            },
            onTap: () {
              _service.requestScrollToActive();
            },
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: _kSize,
                height: _kSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Circular Video Player
                    ClipOval(
                      child: SizedBox(
                        width: _kSize,
                        height: _kSize,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width > 0
                                ? controller.value.size.width
                                : _kSize,
                            height: controller.value.size.height > 0
                                ? controller.value.size.height
                                : _kSize,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    ),

                    // 2. Smooth Circular Progress Ring
                    Positioned.fill(
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: targetProgress),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.linear,
                          builder: (context, smoothProgress, _) {
                            return CustomPaint(
                              painter: _FloatingProgressPainter(
                                progress: smoothProgress,
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // 3. Subtle Outer Glass Border
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 4. Close Button in Top Corner
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          _service.stopActivePlayback();
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _FloatingProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -3.141592653589793 / 2; // 12 o'clock
    final sweepAngle = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FloatingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
