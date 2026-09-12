import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'message_status_widget.dart';

/// Круглое видеосообщение («кружочек») в стиле Telegram.
/// - Автовоспроизведение без звука (mute, loop) при появлении в чате.
/// - Тап → воспроизведение со звуком с начала.
/// - Повторный тап во время звука → пауза / продолжение.
/// - Круговой индикатор прогресса (progress ring) по контуру при воспроизведении со звуком.
/// - Плавающая капсула времени и статуса прочтения (✓/✓✓) в правом нижнем углу.
class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;
  final double size;
  final String? senderAvatarUrl;
  final Duration? duration;
  final bool isMe;
  final bool isRead;
  final int sendStatus;
  final String? timeText;
  final VoidCallback? onRetry;

  const VideoMessageWidget({
    Key? key,
    required this.videoUrl,
    this.size = 230.0,
    this.senderAvatarUrl,
    this.duration,
    this.isMe = false,
    this.isRead = false,
    this.sendStatus = 1,
    this.timeText,
    this.onRetry,
  }) : super(key: key);

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  VideoPlayerController? _controller;
  int _initSession = 0;
  bool _hasError = false;
  bool _isPlayingWithSound = false;
  bool _isPausedWithSound = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(VideoMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initSession++;
      _controller?.removeListener(_onVideoUpdate);
      _controller?.dispose();
      _controller = null;
      _hasError = false;
      _isPlayingWithSound = false;
      _isPausedWithSound = false;
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    final currentSession = ++_initSession;
    if (widget.videoUrl.isEmpty) {
      if (mounted && currentSession == _initSession) {
        setState(() => _hasError = true);
      }
      return;
    }

    try {
      final url = widget.videoUrl;
      final uri = Uri.tryParse(url);
      final isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

      VideoPlayerController controller;
      if (isNetwork) {
        controller = VideoPlayerController.networkUrl(uri);
      } else {
        final filePath = url.startsWith('file://') ? url.replaceFirst('file://', '') : url;
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('[VideoMessageWidget] File does not exist: $filePath');
          if (mounted && currentSession == _initSession) {
            setState(() => _hasError = true);
          }
          return;
        }
        controller = VideoPlayerController.file(file);
      }

      try {
        await controller.initialize();
      } catch (initErr) {
        if (isNetwork) {
          debugPrint('[VideoMessageWidget] Network video init failed: $initErr, attempting local fallback');
          final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
          File? localFallback;
          if (fileName.isNotEmpty) {
            try {
              final tempDir = await getTemporaryDirectory();
              final candidate = File('${tempDir.path}/$fileName');
              if (await candidate.exists()) {
                localFallback = candidate;
              }
            } catch (_) {}
          }
          if (localFallback != null) {
            await controller.dispose();
            controller = VideoPlayerController.file(localFallback);
            await controller.initialize();
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      await controller.setLooping(true);
      await controller.setVolume(0.0);

      if (!mounted || currentSession != _initSession) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _controller!.addListener(_onVideoUpdate);
      setState(() {
        _hasError = false;
      });
      _controller!.play();
    } catch (e) {
      debugPrint('[VideoMessageWidget] Failed to initialize video: $e');
      if (mounted && currentSession == _initSession) {
        setState(() => _hasError = true);
      }
    }
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    // Only trigger widget rebuilds when playing with sound (for the progress ring and countdown).
    // Muted looping playback is rendered directly to the hardware texture with 0 widget rebuilds.
    if (!_isPlayingWithSound) return;
    setState(() {});
  }

  @override
  void dispose() {
    _initSession++;
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _handleTap() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isPlayingWithSound) {
      if (_controller!.value.isPlaying) {
        // Pause sound playback
        _controller?.pause();
        setState(() => _isPausedWithSound = true);
      } else {
        // Resume sound playback
        _controller?.play();
        setState(() => _isPausedWithSound = false);
      }
    } else {
      // Switch to sound playback from beginning
      _controller?.pause();
      _controller?.seekTo(Duration.zero);
      _controller?.setVolume(1.0);
      _controller?.play();
      setState(() {
        _isPlayingWithSound = true;
        _isPausedWithSound = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDiameter = widget.size;
    final isInitialized = _controller != null && _controller!.value.isInitialized;
    final duration = _controller?.value.duration ?? widget.duration ?? Duration.zero;
    final position = _controller?.value.position ?? Duration.zero;

    final double progress;
    if (duration.inMilliseconds > 0 && isInitialized) {
      progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
        width: effectiveDiameter,
        height: effectiveDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Circular Video / Placeholder / Error
            ClipOval(
              child: SizedBox(
                width: effectiveDiameter,
                height: effectiveDiameter,
                child: _hasError
                    ? Container(
                        color: Colors.black87,
                        child: Center(
                          child: widget.onRetry != null
                              ? IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 36),
                                  onPressed: () {
                                    setState(() {
                                      _hasError = false;
                                    });
                                    _initializeVideoPlayer();
                                  },
                                )
                              : const Icon(Icons.error_outline, color: Colors.white70, size: 36),
                        ),
                      )
                    : !isInitialized
                        ? Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white70,
                              ),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.size.width > 0
                                  ? _controller!.value.size.width
                                  : effectiveDiameter,
                              height: _controller!.value.size.height > 0
                                  ? _controller!.value.size.height
                                  : effectiveDiameter,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
              ),
            ),

            // 2. Play / Pause Overlay Icon when paused with sound
            if (_isPlayingWithSound && _isPausedWithSound)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 28),
                ),
              ),

            // 3. Circular Progress Ring around edge (Active during sound playback)
            if (_isPlayingWithSound && isInitialized)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CircularProgressPainter(
                      progress: progress,
                      color: Colors.white,
                      strokeWidth: 3.0,
                    ),
                  ),
                ),
              ),

            // 4. Subtle Outer Border
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            // 5. Floating Time & Status Pill (Bottom-Right)
            Positioned(
              bottom: 8,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time Text
                    Text(
                      _isPlayingWithSound && isInitialized
                          ? _formatDuration(duration - position)
                          : (widget.timeText ??
                              (duration.inSeconds > 0
                                  ? _formatDuration(duration)
                                  : '0:00')),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),

                    // Outgoing Status (if sent by current user)
                    if (widget.isMe) ...[
                      const SizedBox(width: 4),
                      if (widget.sendStatus == 0)
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: Colors.white70,
                          ),
                        )
                      else if (widget.sendStatus == 2)
                        GestureDetector(
                          onTap: widget.onRetry,
                          child: const iconoir.WarningCircle(
                            width: 13,
                            height: 13,
                            color: Colors.redAccent,
                          ),
                        )
                      else
                        MessageStatusWidget(
                          isRead: widget.isRead,
                          isOutgoing: true,
                          colorOverride: Colors.white,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// Painter for circular progress ring around the video message
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track circle
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc from 12 o'clock (-pi/2) clockwise
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

