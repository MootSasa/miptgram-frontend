import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;

  const VideoCallScreen({
    Key? key,
    required this.callId,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final RTCVideoRenderer _localRenderer;
  late final RTCVideoRenderer _remoteRenderer;
  late RTCPeerConnection _peerConnection;
  MediaStream? _localStream;
  bool _isInitialized = false;
  bool _isCallEnded = false;

  // STUN servers for WebRTC connection
  static final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _initializePeerConnection();
  }

  Future<void> _initializeRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initializePeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      // Send ICE candidate to remote peer via signaling
      _sendSignalingMessage({
        'type': 'ice-candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
  
    _peerConnection.onIceConnectionState = (RTCIceConnectionState state) {
      if (mounted) {
        setState(() {
          // Handle connection state changes
          if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
            // Call connected
          } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
            _handleCallEnded();
          }
        });
      }
    };

    _peerConnection.onAddStream = (MediaStream stream) {
      _remoteRenderer.srcObject = stream;
    };

    _peerConnection.onRemoveStream = (MediaStream stream) {
      _remoteRenderer.srcObject = null;
    };

    _getUserMedia().then((stream) {
      if (!mounted) return;
      _localStream = stream;
      _localRenderer.srcObject = stream;

      // Add local stream to peer connection
      stream.getTracks().forEach((track) {
        _peerConnection.addTrack(track, stream);
      });

      setState(() => _isInitialized = true);

      // If caller, create offer
      if (widget.isCaller) {
        _createOffer();
      }
    }).catchError((e) {
      debugPrint('Error accessing media: $e');
      // Handle error - show error UI
    });
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    return await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<void> _createOffer() async {
    final offer = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(offer);
    _sendSignalingMessage({
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  /// Handles incoming signaling messages from the remote peer.
  /// This method should be called when a signaling message is received from the server.
  Future<void> handleSignalingMessage(Map<String, dynamic> message) async {
    if (!_isInitialized) return;

    final String type = message['type'];
    if (type == 'offer') {
      await _peerConnection.setRemoteDescription(
        RTCSessionDescription(message['sdp'], 'offer'),
      );
      final answer = await _peerConnection.createAnswer();
      await _peerConnection.setLocalDescription(answer);
      _sendSignalingMessage({
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } else if (type == 'answer') {
      await _peerConnection.setRemoteDescription(
        RTCSessionDescription(message['sdp'], 'answer'),
      );
    } else if (type == 'ice-candidate') {
      final candidate = message['candidate'];
      if (candidate != null) {
        await _peerConnection.addCandidate(
          RTCIceCandidate(
            candidate['candidate'],
            candidate['sdpMid'],
            candidate['sdpMLineIndex'],
          ),
        );
      }
    }
  }

  void _sendSignalingMessage(Map<String, dynamic> message) {
    // In a real app, this would send the message via your signaling service (e.g., gRPC)
    // For now, we'll just log it - replace with actual signaling implementation
    debugPrint('Sending signaling message: $message');
    // Example: context.read<CallBloc>().add(SendSignalingEvent(message));
  }

  void _handleCallEnded() {
    if (_isCallEnded) return;
    setState(() => _isCallEnded = true);
    _peerConnection.close();
    _localStream?.dispose();
    // Navigate back or show ended call UI
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(
            child: _remoteRenderer.srcObject != null
                ? RTCVideoView(_remoteRenderer)
                : Container(
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.videocam_off,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
          ),
          // Local video (small overlay)
          Positioned(
            bottom: 20,
            right: 20,
            child: SizedBox(
              width: 120,
              height: 160,
              child: _localRenderer.srcObject != null
                  ? RTCVideoView(_localRenderer)
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.videocam,
                        color: Colors.white70,
                        size: 32,
                      ),
                    ),
            ),
          ),
          // Call controls
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.mic_off,
                    color: Colors.red,
                    size: 36,
                  ),
                  onPressed: () {
                    // Toggle mute
                    final bool muted = _localStream!
                        .getAudioTracks()
                        .first
                        .enabled;
                    _localStream!
                        .getAudioTracks()
                        .first
                        .enabled = !muted;
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.call_end,
                    color: Colors.red,
                    size: 36,
                  ),
                  onPressed: _handleCallEnded,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.videocam_off,
                    color: Colors.red,
                    size: 36,
                  ),
                  onPressed: () {
                    // Toggle video
                    final bool muted = _localStream!
                        .getVideoTracks()
                        .first
                        .enabled;
                    _localStream!
                        .getVideoTracks()
                        .first
                        .enabled = !muted;
                  },
                ),
              ],
            ),
          ),
          // Connection status
          if (!_isInitialized)
            const Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}