import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Global/chat playback coordination service for video notes («кружочки»).
/// Features:
/// - Single active playing video note at any time (with sound).
/// - Continuous playback queue: invokes [onPlayNextRequested] when current note finishes.
/// - Floating picture-in-picture (PiP): manages floating state & draggable coordinates
///   when the active video note scrolls out of the chat viewport.
class VideoNotePlaybackService with ChangeNotifier {
  static final VideoNotePlaybackService _instance = VideoNotePlaybackService._internal();
  factory VideoNotePlaybackService() => _instance;
  VideoNotePlaybackService._internal();

  String? _activeMessageId;
  String? _activeVideoUrl;
  VideoPlayerController? _activeController;
  bool _isFloating = false;
  bool _isInView = true;
  Offset _floatingPosition = const Offset(20, 96);
  final Set<String> _visibleMessageIds = <String>{};
  
  // Callback registered by the active chat screen to advance to next video note
  void Function(String currentMessageId)? onPlayNextRequested;
  // Callback registered to scroll to the active message in chat
  void Function(String messageId)? onScrollToMessageRequested;

  String? get activeMessageId => _activeMessageId;
  String? get activeVideoUrl => _activeVideoUrl;
  VideoPlayerController? get activeController => _activeController;
  bool get isFloating => _isFloating && _activeController != null;
  bool get isInView => _isInView;
  Offset get floatingPosition => _floatingPosition;
  bool isMessageInView(String messageId) => _visibleMessageIds.contains(messageId);

  void updateFloatingPosition(Offset newPos) {
    _floatingPosition = newPos;
    notifyListeners();
  }

  void setActivePlayback({
    required String messageId,
    required String videoUrl,
    required VideoPlayerController controller,
    bool? initialInView,
  }) {
    if (_activeMessageId != null && _activeMessageId != messageId) {
      // Previous controller reverts to muted loop
      if (_activeController != null && _activeController != controller) {
        try {
          _activeController!.setVolume(0.0);
        } catch (_) {}
      }
    }
    _activeMessageId = messageId;
    _activeVideoUrl = videoUrl;
    _activeController = controller;

    final inView = initialInView ?? (_visibleMessageIds.isEmpty ? true : _visibleMessageIds.contains(messageId));
    _isInView = inView;
    _isFloating = !inView;
    notifyListeners();
  }

  void stopActivePlayback([String? messageId]) {
    if (messageId != null && _activeMessageId != messageId) return;
    if (_activeController != null) {
      try {
        _activeController!.setVolume(0.0);
        _activeController!.pause();
      } catch (_) {}
    }
    _activeMessageId = null;
    _activeVideoUrl = null;
    _activeController = null;
    _isFloating = false;
    _isInView = true;
    _visibleMessageIds.clear();
    notifyListeners();
  }

  void setInView(String messageId, bool inView) {
    if (inView) {
      _visibleMessageIds.add(messageId);
    } else {
      _visibleMessageIds.remove(messageId);
    }

    if (_activeMessageId == messageId) {
      if (_isInView != inView) {
        _isInView = inView;
        _isFloating = !inView && _activeController != null;
        notifyListeners();
      }
    }
  }

  void onVideoCompleted(String messageId) {
    if (_activeMessageId != messageId) return;
    debugPrint('[VideoNotePlaybackService] Video note $messageId completed, advancing...');
    if (onPlayNextRequested != null) {
      onPlayNextRequested!(messageId);
    } else {
      stopActivePlayback(messageId);
    }
  }

  void requestScrollToActive() {
    if (_activeMessageId != null && onScrollToMessageRequested != null) {
      onScrollToMessageRequested!(_activeMessageId!);
    }
  }
}
