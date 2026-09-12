import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Cross-platform service for recording Telegram-style circular video notes.
/// Uses [flutter_webrtc] for universal platform compatibility (Android, iOS, Windows, macOS, Linux, Web).
class VideoNoteRecorderService with ChangeNotifier {
  RTCVideoRenderer? _renderer;
  MediaStream? _stream;
  MediaRecorder? _recorder;
  Timer? _timer;
  String? _currentFilePath;

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = true;
  Duration _elapsed = Duration.zero;
  String? _errorMessage;

  RTCVideoRenderer? get renderer => _renderer;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isFrontCamera => _isFrontCamera;
  Duration get elapsed => _elapsed;
  String? get errorMessage => _errorMessage;
  String? get currentFilePath => _currentFilePath;

  /// Request permissions and initialize live camera preview stream
  Future<bool> initialize() async {
    if (_isInitialized && _renderer != null && _stream != null) {
      return true;
    }

    try {
      _errorMessage = null;

      // Check / request permissions on mobile / desktop platforms
      if (!kIsWeb) {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        if (cameraStatus.isDenied ||
            cameraStatus.isPermanentlyDenied ||
            micStatus.isDenied ||
            micStatus.isPermanentlyDenied) {
          _errorMessage = 'permission_denied';
          notifyListeners();
          return false;
        }
      }

      _renderer = RTCVideoRenderer();
      await _renderer!.initialize();

      await _acquireStream();

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('VideoNoteRecorderService: Failed to initialize: $e');
      _errorMessage = e.toString();
      _cleanupStream();
      notifyListeners();
      return false;
    }
  }

  Future<void> _acquireStream() async {
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '480',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': _isFrontCamera ? 'user' : 'environment',
        'optional': [],
      },
    };

    _stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (_renderer != null) {
      _renderer!.srcObject = _stream;
    }
  }

  /// Start recording video note to a local file (no 60s limit)
  Future<bool> startRecording() async {
    if (!_isInitialized || _stream == null) {
      final ok = await initialize();
      if (!ok) return false;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      const extension = kIsWeb ? 'webm' : 'mp4';
      _currentFilePath =
          '${tempDir.path}/video_note_${DateTime.now().millisecondsSinceEpoch}.$extension';

      _recorder = MediaRecorder();
      final videoTracks = _stream!.getVideoTracks();
      final videoTrack = videoTracks.isNotEmpty ? videoTracks.first : null;

      await _recorder!.start(
        _currentFilePath!,
        videoTrack: videoTrack,
      );

      _isRecording = true;
      _elapsed = Duration.zero;

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
        _elapsed += const Duration(milliseconds: 100);
        notifyListeners();
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('VideoNoteRecorderService: Failed to start recording: $e');
      _isRecording = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle between front (selfie) and rear cameras during recording or preview
  Future<void> flipCamera() async {
    if (_stream == null) return;
    try {
      _isFrontCamera = !_isFrontCamera;

      // Stop existing video tracks
      for (final track in _stream!.getVideoTracks()) {
        track.stop();
        _stream!.removeTrack(track);
      }

      final videoConstraints = <String, dynamic>{
        'mandatory': {
          'minWidth': '480',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': _isFrontCamera ? 'user' : 'environment',
        'optional': [],
      };

      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': videoConstraints,
      });

      for (final track in newStream.getVideoTracks()) {
        _stream!.addTrack(track);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('VideoNoteRecorderService: Failed to flip camera: $e');
    }
  }

  /// Stop recording and return the finalized video file
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;

    _timer?.cancel();
    _timer = null;
    _isRecording = false;

    try {
      await _recorder?.stop();
      _recorder = null;

      final path = _currentFilePath;
      _currentFilePath = null;

      if (path != null) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          notifyListeners();
          return file;
        }
      }
    } catch (e) {
      debugPrint('VideoNoteRecorderService: Failed to stop recording: $e');
    }

    notifyListeners();
    return null;
  }

  /// Cancel recording and discard the recorded file (e.g. slide to cancel)
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    _isRecording = false;

    try {
      await _recorder?.stop();
      _recorder = null;

      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('VideoNoteRecorderService: Error during cancel: $e');
    } finally {
      _currentFilePath = null;
      _elapsed = Duration.zero;
      notifyListeners();
    }
  }

  void _cleanupStream() {
    _timer?.cancel();
    _timer = null;

    if (_stream != null) {
      for (final track in _stream!.getTracks()) {
        track.stop();
      }
      _stream!.dispose();
      _stream = null;
    }

    _recorder = null;
    _isRecording = false;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _cleanupStream();
    _renderer?.dispose();
    _renderer = null;
    super.dispose();
  }
}
