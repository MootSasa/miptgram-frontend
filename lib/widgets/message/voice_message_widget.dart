import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import '../../services/voice_playback_service.dart';
import 'message_status_widget.dart';

/// Full Telegram-style voice message player widget inside message bubbles.
/// Features:
/// - Play/Pause button with smooth progress.
/// - Multi-bar interactive waveform scrubber with seek-on-drag/tap.
/// - Dynamic duration countdown during playback.
/// - 1X / 1.5X / 2X playback speed pill button.
/// - Unplayed message dot for incoming voice notes.
/// - Send time & delivery status checkmarks.
class VoiceMessageWidget extends StatefulWidget {
  final String messageId;
  final String audioUrl;
  final Duration? duration;
  final List<int>? waveform;
  final bool isMe;
  final bool isRead;
  final int sendStatus;
  final String? timeText;
  final String? senderName;
  final VoidCallback? onRetry;

  const VoiceMessageWidget({
    Key? key,
    required this.messageId,
    required this.audioUrl,
    this.duration,
    this.waveform,
    this.isMe = false,
    this.isRead = false,
    this.sendStatus = 1,
    this.timeText,
    this.senderName,
    this.onRetry,
  }) : super(key: key);

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final VoicePlaybackService _playbackService = VoicePlaybackService();
  bool _hasBeenPlayedLocally = false;

  @override
  void initState() {
    super.initState();
    _playbackService.addListener(_onPlaybackUpdate);
  }

  @override
  void dispose() {
    _playbackService.removeListener(_onPlaybackUpdate);
    super.dispose();
  }

  void _onPlaybackUpdate() {
    if (!mounted) return;
    if (_playbackService.activeMessageId == widget.messageId && _playbackService.isPlaying) {
      if (!_hasBeenPlayedLocally) {
        setState(() => _hasBeenPlayedLocally = true);
        return;
      }
    }
    setState(() {});
  }

  bool get _isThisPlaying =>
      _playbackService.activeMessageId == widget.messageId && _playbackService.isPlaying;

  bool get _isThisActive => _playbackService.activeMessageId == widget.messageId;

  Duration get _effectiveDuration {
    if (_isThisActive && _playbackService.duration > Duration.zero) {
      return _playbackService.duration;
    }
    return widget.duration ?? Duration.zero;
  }

  Duration get _effectivePosition {
    if (_isThisActive) {
      return _playbackService.position;
    }
    return Duration.zero;
  }

  double get _effectiveProgress {
    final dur = _effectiveDuration.inMilliseconds;
    if (dur <= 0) return 0.0;
    return (_effectivePosition.inMilliseconds / dur).clamp(0.0, 1.0);
  }

  void _handlePlayPause() {
    if (_isThisPlaying) {
      _playbackService.pauseVoice();
    } else {
      _playbackService.playVoice(
        messageId: widget.messageId,
        audioUrl: widget.audioUrl,
        senderName: widget.senderName,
        initialDuration: widget.duration,
      );
    }
  }

  void _handleWaveformTap(double localDx, double totalWidth) {
    if (totalWidth <= 0) return;
    final fraction = (localDx / totalWidth).clamp(0.0, 1.0);
    final targetMs = (fraction * _effectiveDuration.inMilliseconds).round();

    if (!_isThisActive) {
      _playbackService.playVoice(
        messageId: widget.messageId,
        audioUrl: widget.audioUrl,
        senderName: widget.senderName,
        initialDuration: widget.duration,
      ).then((_) {
        _playbackService.seekVoice(Duration(milliseconds: targetMs));
      });
    } else {
      _playbackService.seekVoice(Duration(milliseconds: targetMs));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  List<int> _getEffectiveWaveform() {
    if (widget.waveform != null && widget.waveform!.isNotEmpty) {
      return widget.waveform!;
    }
    // Generate deterministic waveform based on messageId
    final hash = widget.messageId.hashCode;
    return List.generate(36, (i) {
      final val = ((math.sin(i * 0.45 + hash) * 12) + 16).round();
      return val.clamp(4, 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    // Outgoing bubble styling vs incoming bubble styling
    final playedColor = widget.isMe ? Colors.white : primaryColor;
    final unplayedColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.4)
        : (isDark ? Colors.white24 : Colors.black26);

    final duration = _effectiveDuration;
    final position = _effectivePosition;
    final progress = _effectiveProgress;
    final waveform = _getEffectiveWaveform();

    final durationText = _isThisActive && _isThisPlaying
        ? _formatDuration(position)
        : (duration > Duration.zero ? _formatDuration(duration) : '0:00');

    final bool showUnplayedDot =
        !widget.isMe && !widget.isRead && !_hasBeenPlayedLocally && !_isThisActive;

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Play / Pause Button
              GestureDetector(
                onTap: _handlePlayPause,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.22)
                        : primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 28,
                      color: widget.isMe ? Colors.white : primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Waveform & Controls
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform Scrubber
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              _handleWaveformTap(details.localPosition.dx, width),
                          onHorizontalDragUpdate: (details) =>
                              _handleWaveformTap(details.localPosition.dx, width),
                          child: SizedBox(
                            width: width,
                            height: 26,
                            child: CustomPaint(
                              painter: _WaveformScrubberPainter(
                                waveform: waveform,
                                progress: progress,
                                playedColor: playedColor,
                                unplayedColor: unplayedColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Duration, Unplayed Dot, and Speed Button Row
                    Row(
                      children: [
                        // Unplayed Blue Dot
                        if (showUnplayedDot) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],

                        // Duration text
                        Text(
                          durationText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.85)
                                : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const Spacer(),

                        // Playback Speed Toggle Pill (1X / 1.5X / 2X)
                        if (_isThisActive)
                          GestureDetector(
                            onTap: _playbackService.cyclePlaybackSpeed,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: widget.isMe
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_playbackService.playbackSpeed.toString().replaceAll('.0', '')}X',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isMe ? Colors.white : primaryColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Time and Status pill row
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.timeText != null && widget.timeText!.isNotEmpty)
                    Text(
                      widget.timeText!,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
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
                        isOutgoing: widget.isMe,
                        colorOverride: Colors.white.withValues(alpha: 0.7),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformScrubberPainter extends CustomPainter {
  final List<int> waveform;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformScrubberPainter({
    required this.waveform,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty || size.width <= 0) return;

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    final barCount = waveform.length;
    final gap = size.width / barCount;
    final centerY = size.height / 2;
    final progressX = progress * size.width;

    for (int i = 0; i < barCount; i++) {
      final x = (i * gap) + (gap / 2);
      final heightRatio = (waveform[i] / 31.0).clamp(0.12, 1.0);
      final barHeight = math.max(3.0, heightRatio * size.height * 0.95);

      final paint = (x <= progressX) ? playedPaint : unplayedPaint;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformScrubberPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor ||
        oldDelegate.waveform != waveform;
  }
}
