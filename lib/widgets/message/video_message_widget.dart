import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/video_note_playback_service.dart';
import 'message_status_widget.dart';

/// Static LRU pool for caching active video note controllers to avoid re-initialization
/// and loading spinners when scrolling back and forth.
class VideoNoteControllerPool {
  static final Map<String, VideoPlayerController> _pool = {};
  static final List<String> _order = [];
  static const int _maxControllers = 12;

  static VideoPlayerController? get(String url) => _pool[url];

  static void put(String url, VideoPlayerController controller) {
    if (_pool.containsKey(url)) return;
    if (_order.length >= _maxControllers) {
      final oldest = _order.removeAt(0);
      final oldCtrl = _pool.remove(oldest);
      try {
        oldCtrl?.dispose();
      } catch (_) {}
    }
    _pool[url] = controller;
    _order.add(url);
  }
}

/// Круглое видеосообщение («кружочек») в стиле Telegram.
/// - Автовоспроизведение без звука (mute, loop) при появлении в чате.
/// - Тап → воспроизведение со звуком с начала, плавное увеличение размера.
/// - Повторный тап во время звука → пауза / продолжение.
/// - Плавный (60 FPS) круговой индикатор прогресса (progress ring) по контуру.
/// - При завершении воспроизведения автоматически переходит к следующему кружку.
/// - При уходе из поля зрения появляется плавающее окно (PiP) в углу экрана.
/// - Отсутствие мерцания и повторной анимации загрузки при скролле (KeepAlive + Cache Pool).
class VideoMessageWidget extends StatefulWidget {
  final String videoUrl;
  final String? messageId;
  final double size;
  final String? senderAvatarUrl;
  final Duration? duration;
  final bool isMe;
  final bool isRead;
  final int sendStatus;
  final String? timeText;
  final String? senderName;
  final VoidCallback? onRetry;

  const VideoMessageWidget({
    Key? key,
    required this.videoUrl,
    this.messageId,
    this.size = 230.0,
    this.senderAvatarUrl,
    this.duration,
    this.isMe = false,
    this.isRead = false,
    this.sendStatus = 1,
    this.timeText,
    this.senderName,
    this.onRetry,
  }) : super(key: key);

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  int _initSession = 0;
  bool _hasError = false;
  bool _isPlayingWithSound = false;
  bool get _isPausedWithSound =>
      _isPlayingWithSound && !(_controller?.value.isPlaying ?? false);
  double _prevProgress = 0.0;
  final VideoNotePlaybackService _playbackService = VideoNotePlaybackService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _playbackService.addListener(_onPlaybackServiceUpdate);
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(VideoMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initSession++;
      _controller?.removeListener(_onVideoUpdate);
      _controller = null;
      _hasError = false;
      _isPlayingWithSound = false;
      _prevProgress = 0.0;
      _initializeVideoPlayer();
    }
  }

  void _onPlaybackServiceUpdate() {
    if (!mounted || widget.messageId == null) return;
    final activeId = _playbackService.activeMessageId;
    if (activeId == widget.messageId) {
      if (!_isPlayingWithSound && _controller != null && _controller!.value.isInitialized) {
        _startSoundPlayback();
      }
    } else {
      if (_isPlayingWithSound) {
        _revertToMutedLoop();
      }
    }
    setState(() {});
  }

  Future<void> _initializeVideoPlayer() async {
    final currentSession = ++_initSession;
    if (widget.videoUrl.isEmpty) {
      if (mounted && currentSession == _initSession) {
        setState(() => _hasError = true);
      }
      return;
    }

    // 1. Check Controller Pool for instantaneous zero-delay restore
    final cached = VideoNoteControllerPool.get(widget.videoUrl);
    if (cached != null && cached.value.isInitialized) {
      _controller = cached;
      _controller!.addListener(_onVideoUpdate);
      if (mounted) {
        setState(() {
          _hasError = false;
        });
      }
      if (!_controller!.value.isPlaying) {
        _controller!.play();
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
      VideoNoteControllerPool.put(widget.videoUrl, controller);

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
    if (!_isPlayingWithSound) return;

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final position = controller.value.position;
      final duration = controller.value.duration;

      final bool isCompleted = (duration.inMilliseconds > 0) &&
          (position >= duration || (!controller.value.isPlaying && position >= duration - const Duration(milliseconds: 150)));
      if (isCompleted) {
        _revertToMutedLoop();
        if (widget.messageId != null) {
          _playbackService.onVideoCompleted(widget.messageId!);
        }
        return;
      }
    }

    setState(() {});
  }

  void _startSoundPlayback() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _controller?.pause();
    _controller?.seekTo(Duration.zero);
    _controller?.setLooping(false);
    _controller?.setVolume(1.0);
    _controller?.play();
    _prevProgress = 0.0;
    setState(() {
      _isPlayingWithSound = true;
    });
  }

  void _revertToMutedLoop() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _controller?.seekTo(Duration.zero);
    _controller?.setLooping(true);
    _controller?.setVolume(0.0);
    if (!_controller!.value.isPlaying) {
      _controller?.play();
    }
    setState(() {
      _isPlayingWithSound = false;
      _prevProgress = 0.0;
    });
  }

  @override
  void dispose() {
    _initSession++;
    _playbackService.removeListener(_onPlaybackServiceUpdate);
    if (widget.messageId != null) {
      _playbackService.setInView(widget.messageId!, false);
    }
    _controller?.removeListener(_onVideoUpdate);
    // Note: Controller is preserved in VideoNoteControllerPool for instant scroll restore
    _controller = null;
    super.dispose();
  }

  void _handleTap() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isPlayingWithSound) {
      _playbackService.togglePlayPause();
    } else {
      if (widget.messageId != null) {
        _playbackService.setActivePlayback(
          messageId: widget.messageId!,
          videoUrl: widget.videoUrl,
          controller: _controller!,
          senderName: widget.isMe ? null : widget.senderName,
          initialInView: true,
        );
      }
      _startSoundPlayback();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildDurationPill(String durationText) {
    return Container(
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
          Icon(
            _isPlayingWithSound ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
            size: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 3),
          Text(
            durationText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePill(BuildContext context) {
    final hasTime = widget.timeText != null && widget.timeText!.isNotEmpty;
    if (!hasTime && !widget.isMe) {
      return const SizedBox.shrink();
    }
    return Container(
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
          if (hasTime)
            Text(
              widget.timeText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (widget.isMe) ...[
            if (hasTime) const SizedBox(width: 4),
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
                isOutgoing: widget.isMe,
                colorOverride: Colors.white,
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    // Passive size is slightly smaller (~188px), expands to ~260px on active sound playback
    final double passiveDiameter = math.min(192.0, screenWidth * 0.52);
    final double activeDiameter = math.min(265.0, screenWidth * 0.74);
    final double effectiveDiameter = _isPlayingWithSound ? activeDiameter : passiveDiameter;

    final isInitialized = _controller != null && _controller!.value.isInitialized;
    final duration = _controller?.value.duration ?? widget.duration ?? Duration.zero;
    final position = _controller?.value.position ?? Duration.zero;

    final double progress;
    if (duration.inMilliseconds > 0 && isInitialized) {
      progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    final animatedBeginProgress = (progress < _prevProgress) ? 0.0 : _prevProgress;
    _prevProgress = progress;

    final String durationText;
    if (_isPlayingWithSound && isInitialized) {
      durationText = _formatDuration(duration - position);
    } else if (duration.inSeconds > 0) {
      durationText = _formatDuration(duration);
    } else if (widget.duration != null && widget.duration!.inSeconds > 0) {
      durationText = _formatDuration(widget.duration!);
    } else {
      durationText = '0:00';
    }

    return VisibilityDetector(
      key: Key('vnote_${widget.messageId ?? widget.videoUrl}'),
      onVisibilityChanged: (info) {
        if (widget.messageId != null) {
          final inView = info.visibleFraction >= 0.15;
          _playbackService.setInView(widget.messageId!, inView);
        }
      },
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
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
                    // 1. Circular Video / Placeholder / Error (No spinning loader!)
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
                                    color: const Color(0xFF1C1C1E),
                                    child: const Center(
                                      child: Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 42),
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

                    // 3. Smooth Circular Progress Ring around edge (Active during sound playback)
                    if (_isPlayingWithSound && isInitialized)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: animatedBeginProgress, end: progress),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.linear,
                            builder: (context, smoothProgress, _) {
                              return CustomPaint(
                                painter: _CircularProgressPainter(
                                  progress: smoothProgress,
                                  color: Colors.white,
                                  strokeWidth: 3.0,
                                ),
                              );
                            },
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5.0),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: effectiveDiameter,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDurationPill(durationText),
                  _buildTimePill(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 o'clock
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
