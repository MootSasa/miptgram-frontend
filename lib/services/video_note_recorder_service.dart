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

  /// Checks whether both camera and microphone permissions are currently granted.
  Future<bool> hasPermissions() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    try {
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      return (cam.isGranted || cam.isLimited) &&
          (mic.isGranted || mic.isLimited);
    } catch (_) {
      return true;
    }
  }

  /// Checks whether either camera or microphone permission is permanently denied.
  Future<bool> isPermanentlyDenied() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      return cam.isPermanentlyDenied || mic.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  /// Requests camera and microphone permissions together in a single native request dialog batch.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cam = statuses[Permission.camera];
      final mic = statuses[Permission.microphone];

      final camOk = cam?.isGranted == true || cam?.isLimited == true;
      final micOk = mic?.isGranted == true || mic?.isLimited == true;

      return camOk && micOk;
    } catch (_) {
      return true;
    }
  }

  /// Request permissions and initialize live camera preview stream
  Future<bool> initialize() async {
    if (_isInitialized && _renderer != null && _stream != null) {
      return true;
    }

    try {
      _errorMessage = null;

      final ok = await requestPermissions();
      if (!ok) {
        _errorMessage = 'permission_denied';
        notifyListeners();
        return false;
      }

      _renderer = RTCVideoRenderer();
      await _renderer!.initialize();

      await _acquireStream();

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('VideoNoteRecorderService: Failed to initialize: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') ||
          errorStr.contains('notallowed') ||
          errorStr.contains('denied')) {
        _errorMessage = 'permission_denied';
      } else {
        _errorMessage = e.toString();
      }
      _cleanupStream();
      notifyListeners();
      return false;
    }
  }

  Future<void> _acquireStream() async {
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'optional': [],
        },
      };
      _stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      debugPrint(
          'VideoNoteRecorderService: Failed with mandatory constraints, retrying basic: $e');
      final fallbackConstraints = <String, dynamic>{
        'audio': true,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
        },
      };
      _stream = await navigator.mediaDevices.getUserMedia(fallbackConstraints);
    }

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

      if (!kIsWeb) {
        await _recorder!.start(
          _currentFilePath!,
          videoTrack: videoTrack,
          audioChannel: RecorderAudioChannel.INPUT,
        );
      } else {
        _recorder!.startWeb(
          _stream!,
          mimeType: 'video/webm',
        );
      }

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
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') ||
          errorStr.contains('notallowed') ||
          errorStr.contains('denied')) {
        _errorMessage = 'permission_denied';
      } else {
        _errorMessage = e.toString();
      }
      notifyListeners();
      return false;
    }
  }

  /// Toggle between front (selfie) and rear cameras during recording or preview
  Future<void> flipCamera() async {
    if (_stream == null) return;
    final videoTracks = _stream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    try {
      final track = videoTracks.first;
      if (!kIsWeb) {
        try {
          final isFront = await Helper.switchCamera(track);
          _isFrontCamera = isFront;
        } catch (e) {
          debugPrint('VideoNoteRecorderService: switchCamera error, toggling flag: $e');
          _isFrontCamera = !_isFrontCamera;
        }
      } else {
        final cams = await Helper.cameras;
        if (cams.length > 1) {
          final otherCam = cams.firstWhere(
            (c) => _isFrontCamera
                ? (c.label.toLowerCase().contains('back') ||
                    c.label.toLowerCase().contains('rear') ||
                    c.label.toLowerCase().contains('environment'))
                : (c.label.toLowerCase().contains('front') ||
                    c.label.toLowerCase().contains('user')),
            orElse: () => cams.firstWhere((c) => c.deviceId != track.id,
                orElse: () => cams.first),
          );
          await Helper.switchCamera(track, otherCam.deviceId, _stream);
          _isFrontCamera = !_isFrontCamera;
        }
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
        // MediaMuxer on mobile flushes asynchronously on background thread.
        // Poll for up to 3 seconds for the file to be flushed and non-empty.
        for (int i = 0; i < 30; i++) {
          if (await file.exists() && await file.length() > 0) {
            debugPrint(
                'VideoNoteRecorderService: Video note recorded: ${file.path} (${await file.length()} bytes)');
            notifyListeners();
            return file;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (await file.exists() && await file.length() > 0) {
          notifyListeners();
          return file;
        }
        debugPrint('VideoNoteRecorderService: File at $path is missing or empty');
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
