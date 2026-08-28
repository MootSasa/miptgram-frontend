import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A widget that detects when a message becomes visible on screen
/// and triggers a callback. Used for marking messages as read
/// when the user actually sees them.
///
/// The message is considered "seen" when it's at least [visibilityThreshold]
/// visible for [visibleDuration] continuous milliseconds.
class VisibleMessageDetector extends StatefulWidget {
  final String messageId;
  final Widget child;
  final VoidCallback onMessageSeen;
  final double visibilityThreshold;
  final Duration visibleDuration;

  const VisibleMessageDetector({
    Key? key,
    required this.messageId,
    required this.child,
    required this.onMessageSeen,
    this.visibilityThreshold = 0.5,
    this.visibleDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<VisibleMessageDetector> createState() => _VisibleMessageDetectorState();
}

class _VisibleMessageDetectorState extends State<VisibleMessageDetector> {
  bool _hasBeenSeen = false;
  DateTime? _firstVisibleAt;

  @override
  Widget build(BuildContext context) {
    if (_hasBeenSeen) {
      // Already seen, no need to track anymore
      return widget.child;
    }

    return VisibilityDetector(
      key: Key('msg_visibility_${widget.messageId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_hasBeenSeen) return;

    final visibleFraction = info.visibleFraction;

    if (visibleFraction >= widget.visibilityThreshold) {
      // Message is sufficiently visible
      final now = DateTime.now();
      _firstVisibleAt ??= now;

      final elapsed = now.difference(_firstVisibleAt!);
      if (elapsed >= widget.visibleDuration) {
        // Message has been visible long enough — mark as seen
        _hasBeenSeen = true;
        widget.onMessageSeen();
      }
    } else {
      // Message is no longer sufficiently visible — reset timer
      _firstVisibleAt = null;
    }
  }
}
