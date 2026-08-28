import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String? voiceMessageUrl; // URL of the voice message to play (if null, recording mode)
  final Function(String)? onRecordComplete; // Callback when recording is complete

  const VoiceMessageWidget({
    Key? key,
    this.voiceMessageUrl,
    this.onRecordComplete,
  }) : super(key: key);

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  late final AudioPlayer _player;
  bool _isRecording = false;
  bool _isPlaying = false;
  double _progress = 0.0;
  String? _recordedFilePath;
  StreamSubscription<Duration>? _positionSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    // Request permissions
    final hasPermission = await _requestPermissions();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      
      // Set up playback progress subscription only if we have a valid URL to play
      if (hasPermission && widget.voiceMessageUrl != null && widget.voiceMessageUrl!.isNotEmpty) {
        _setupPlaybackProgressSubscription();
      }
    }
  }

  Future<bool> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    return status.isGranted;
  }

  void _setupPlaybackProgressSubscription() {
    _positionSubscription = _player.positionStream.listen((position) {
      final duration = _player.duration;
      if (duration != null && mounted) {
        setState(() {
          _progress = duration.inMilliseconds > 0 
              ? position.inMilliseconds / duration.inMilliseconds 
              : 0.0;
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      // Check permission
      if (!await _recorder.hasPermission()) {
        throw RecordingPermissionException('Microphone permission not granted');
      }

      // Create a temporary file path for recording
      final dir = await getTemporaryDirectory();
      _recordedFilePath = '${dir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _recordedFilePath!,
      );
      
      if (mounted) {
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      rethrow;
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (mounted) {
      setState(() => _isRecording = false);
    }
    if (path != null && widget.onRecordComplete != null) {
      widget.onRecordComplete!(path);
    }
  }

  Future<void> _play() async {
    if (widget.voiceMessageUrl == null || widget.voiceMessageUrl!.isEmpty) {
      return;
    }
    
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.setUrl(widget.voiceMessageUrl!);
        await _player.play();
      }
      if (mounted) {
        setState(() => _isPlaying = !_isPlaying);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _seekTo(double value) {
    final duration = _player.duration;
    if (duration != null) {
      final position = value * duration.inMilliseconds;
      _player.seek(Duration(milliseconds: position.round()));
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const CircularProgressIndicator();
    }
    
    if (widget.voiceMessageUrl == null) {
      // Recording mode
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: _isRecording ? Colors.red : null,
              size: 36,
            ),
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
          if (_isRecording)
            const Text(
              'Recording...',
              style: TextStyle(color: Colors.red),
            ),
        ],
      );
    } else {
      // Playback mode
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 36,
            ),
            onPressed: _play,
          ),
          Slider(
            value: _progress.clamp(0.0, 1.0),
            onChanged: _seekTo,
            activeColor: Theme.of(context).primaryColor,
          ),
          Text(
            '${_player.position.inSeconds}/${_player.duration?.inSeconds ?? 0}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    }
  }
}

class RecordingPermissionException implements Exception {
  final String message;
  RecordingPermissionException(this.message);
  
  @override
  String toString() => 'RecordingPermissionException: $message';
}
