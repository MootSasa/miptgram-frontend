import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Круглое видеосообщение («кружочек»).
/// Автовоспроизведение (mute, loop) при появлении.
/// Тап → воспроизведение со звуком. Повторный тап → пауза.
/// Прогресс-бар по окружности при воспроизведении со звуком.
class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;
  final double size;
  final String? senderAvatarUrl;
  final Duration? duration;

  const VideoMessageWidget({
    Key? key,
    required this.videoUrl,
    this.size = 100.0,
    this.senderAvatarUrl,
    this.duration,
  }) : super(key: key);

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  VideoPlayerController? _controller;
  bool _hasError = false;
  bool _isPlayingWithSound = false;
  bool _hasPlayedOnce = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(VideoMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _hasError = false;
      _isPlayingWithSound = false;
      _hasPlayedOnce = false;
      _initializeVideoPlayer();
    }
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..setVolume(0.0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller?.play();
        }
      }).catchError((error) {
        if (mounted) setState(() => _hasError = true);
      });

    _controller?.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    setState(() {}); // Rebuild for progress ring
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isPlayingWithSound) {
      // Currently playing with sound → pause
      _controller?.pause();
      setState(() => _isPlayingWithSound = false);
    } else {
      // Play with sound
      _controller?.setVolume(1.0);
      _controller?.play();
      setState(() {
        _isPlayingWithSound = true;
        _hasPlayedOnce = true;
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
    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular video
            ClipOval(
              child: _hasError
                  ? Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error_outline, color: Colors.red[400], size: widget.size * 0.4),
                    )
                  : _controller == null || !_controller!.value.isInitialized
                      ? Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                        )
                      : VideoPlayer(_controller!),
            ),

            // Avatar overlay (shown before first play)
            if (!_hasPlayedOnce && widget.senderAvatarUrl != null)
              ClipOval(
                child: Container(
                  width: widget.size * 0.5,
                  height: widget.size * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.network(
                      widget.senderAvatarUrl!,
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.white, size: widget.size * 0.25),
                    ),
                  ),
                ),
              ),

            // Play/Pause icon overlay when playing with sound
            if (_isPlayingWithSound && _controller != null && _controller!.value.isPlaying)
              Container(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pause, color: Colors.white, size: 16),
              ),

            // Play icon when paused during sound playback
            if (_isPlayingWithSound && _controller != null && !_controller!.value.isPlaying)
              Container(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
              ),

            // Progress ring when playing with sound
            if (_isPlayingWithSound && _controller != null && _controller!.value.isInitialized)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CircularProgressPainter(
                    progress: _controller!.value.position.inMilliseconds /
                        _controller!.value.duration.inMilliseconds,
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),

            // Duration label
            if (_controller != null && _controller!.value.isInitialized)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isPlayingWithSound
                        ? _formatDuration(_controller!.value.duration - _controller!.value.position)
                        : _formatDuration(_controller!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
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

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -Math.pi / 2;
    final sweepAngle = 2 * Math.pi * progress.clamp(0.0, 1.0);
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
    return oldDelegate.progress != progress;
  }
}

