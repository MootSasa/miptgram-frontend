import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;

  const VoiceCallScreen({
    Key? key,
    required this.callId,
    required this.isCaller,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  bool _isCalling = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  final List<Map<String, dynamic>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    _localStream?.dispose();
    _remoteStream?.dispose();
    super.dispose();
  }

  void _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initialize() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      _localRenderer.srcObject = _localStream;
      setState(() {});
      await _createPeerConnection();
      if (widget.isCaller) {
        await _createOffer();
      } else {
        // TODO: Implement actual signaling for callee to receive offer from caller
        }
    } catch (e) {
      debugPrint('Error initializing voice call: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': _iceServers,
    };
    _peerConnection = await createPeerConnection(configuration);
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      // Send candidate to remote peer via signaling
      debugPrint('ICE candidate: $candidate');
    };
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        setState(() {
          _isCalling = true;
        });
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _hangUp();
      }
    };
    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      _remoteRenderer.srcObject = _remoteStream;
      setState(() {});
    };
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  Future<void> _createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    // Send offer to remote peer via signaling
    debugPrint('Offer created: $offer.sdp');
  }

  void _hangUp() {
    _peerConnection?.close();
    _localStream?.dispose();
    _remoteStream?.dispose();
    Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _localStream!.getAudioTracks()[0].enabled = !_isMuted;
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: Implement platform-specific WebRTC speaker control
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isCalling
                        ? 'Connected'
                        : (widget.isCaller ? 'Calling...' : 'Incoming Call'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'User Name',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.red : Colors.white,
                      size: 36,
                    ),
                    onPressed: _toggleMute,
                  ),
                  IconButton(
                    icon: Icon(
                      _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: _toggleSpeaker,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.call_end,
                      color: Colors.red,
                      size: 36,
                    ),
                    onPressed: _hangUp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}