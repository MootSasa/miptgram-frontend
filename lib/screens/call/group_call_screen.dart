import 'package:flutter/material.dart';

class GroupCallScreen extends StatefulWidget {
  final String callId;
  final String userId;

  const GroupCallScreen({
    Key? key,
    required this.callId,
    required this.userId,
  }) : super(key: key);

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  // Local user state
  bool _isMuted = false;
  bool _isVideoOn = true;

  // List of all participants (including local user)
  late List<Participant> _participants;

  @override
  void initState() {
    super.initState();
    // Initialize with local user and some dummy remote participants
    _participants = [
      Participant(
        id: 'local',
        name: 'You',
        isMuted: _isMuted,
        isVideoOn: _isVideoOn,
        isLocal: true,
      ),
      Participant(
        id: 'remote1',
        name: 'Alice',
        isMuted: false,
        isVideoOn: true,
        isLocal: false,
      ),
      Participant(
        id: 'remote2',
        name: 'Bob',
        isMuted: true,
        isVideoOn: false,
        isLocal: false,
      ),
      Participant(
        id: 'remote3',
        name: 'Charlie',
        isMuted: false,
        isVideoOn: true,
        isLocal: false,
      ),
    ];
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      // Update local participant's mute state
      final localIndex =
      _participants.indexWhere((p) => p.isLocal);
      if (localIndex != -1) {
        _participants[localIndex] = _participants[localIndex].copyWith(
          isMuted: _isMuted,
        );
      }
    });
    // Send mute state change via signaling
    _sendSignalingMessage({
      'type': 'participant-state-change',
      'callId': widget.callId,
      'userId': widget.userId,
      'state': {
        'isMuted': _isMuted,
      },
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOn = !_isVideoOn;
      // Update local participant's video state
      final localIndex =
      _participants.indexWhere((p) => p.isLocal);
      if (localIndex != -1) {
        _participants[localIndex] = _participants[localIndex].copyWith(
          isVideoOn: _isVideoOn,
        );
      }
    });
    // Send video state change via signaling
    _sendSignalingMessage({
      'type': 'participant-state-change',
      'callId': widget.callId,
      'userId': widget.userId,
      'state': {
        'isVideoOn': _isVideoOn,
      },
    });
  }

  void _switchCamera() {
    // Send camera switch request via signaling
    _sendSignalingMessage({
      'type': 'camera-switch',
      'callId': widget.callId,
      'userId': widget.userId,
    });
  }

  /// Sends a signaling message to the server.
  /// In a real app, this would use WebSocket, gRPC stream, or similar.
  void _sendSignalingMessage(Map<String, dynamic> message) {
    // In a real app, this would send the message via your signaling service
    // Example: context.read<CallBloc>().add(SendSignalingEvent(message));
    // Or: _webSocketChannel.sink.add(jsonEncode(message));
    debugPrint('Sending signaling message: $message');
  }

  /// Handles incoming signaling messages from the server.
  /// This method should be called when a signaling message is received.
  void handleSignalingMessage(Map<String, dynamic> message) {
    final String type = message['type'];

    switch (type) {
      case 'participant-state-change':
        _handleParticipantStateChange(message);
        break;
      case 'participant-joined':
        _handleParticipantJoined(message);
        break;
      case 'participant-left':
        _handleParticipantLeft(message);
        break;
      case 'call-ended':
        _handleCallEnded();
        break;
    }
  }

  void _handleParticipantStateChange(Map<String, dynamic> message) {
    final String userId = message['userId'];
    final Map<String, dynamic> state = message['state'];

    setState(() {
      final index = _participants.indexWhere((p) => p.id == userId);
      if (index != -1) {
        final participant = _participants[index];
        _participants[index] = participant.copyWith(
          isMuted: state['isMuted'] as bool?,
          isVideoOn: state['isVideoOn'] as bool?,
        );
      }
    });
  }

  void _handleParticipantJoined(Map<String, dynamic> message) {
    final Map<String, dynamic> participantData = message['participant'];
    final participant = Participant(
      id: participantData['id'] as String,
      name: participantData['name'] as String,
      isMuted: participantData['isMuted'] as bool? ?? false,
      isVideoOn: participantData['isVideoOn'] as bool? ?? true,
      isLocal: false,
    );

    setState(() {
      if (!_participants.any((p) => p.id == participant.id)) {
        _participants.add(participant);
      }
    });
  }

  void _handleParticipantLeft(Map<String, dynamic> message) {
    final String userId = message['userId'];

    setState(() {
      _participants.removeWhere((p) => p.id == userId);
    });
  }

  void _handleCallEnded() {
    // Navigate back or show call ended UI
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Call'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            onPressed: _toggleMute,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
          IconButton(
            icon: Icon(
              _isVideoOn ? Icons.videocam : Icons.videocam_off,
            ),
            onPressed: _toggleVideo,
            tooltip: _isVideoOn ? 'Turn Off Video' : 'Turn On Video',
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final participant = _participants[index];
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: participant.isLocal
                    ? Colors.blue
                    : Colors.grey.shade300,
                width: participant.isLocal ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Video placeholder
                Expanded(
                  flex: 3,
                  child: Container(
                    color: participant.isVideoOn
                        ? Colors.grey.shade200
                        : Colors.grey.shade400,
                    child: Center(
                      child: participant.isVideoOn
                          ? const Icon(
                              Icons.person,
                              size: 48,
                              color: Colors.grey,
                            )
                          : const Icon(
                              Icons.videocam_off,
                              size: 48,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Participant name
                Text(
                  participant.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Mute indicator
                Icon(
                  participant.isMuted
                      ? Icons.mic_off
                      : Icons.mic,
                  color: participant.isMuted
                      ? Colors.red
                      : Colors.green,
                  size: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class Participant {
  final String id;
  final String name;
  final bool isMuted;
  final bool isVideoOn;
  final bool isLocal;

  Participant({
    required this.id,
    required this.name,
    this.isMuted = false,
    this.isVideoOn = true,
    this.isLocal = false,
  });

  Participant copyWith({
    String? id,
    String? name,
    bool? isMuted,
    bool? isVideoOn,
    bool? isLocal,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}