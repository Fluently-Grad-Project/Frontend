import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CallSignalingManager {
  static final CallSignalingManager _instance = CallSignalingManager._internal();

  static CallSignalingManager get instance => _instance;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  factory CallSignalingManager() {
    return _instance;
  }

  CallSignalingManager._internal();

  late WebSocketChannel _channel;
  late String token;

  Function(String roomId, String fromUserName, int fromUserId)? onIncomingCall;
  Function(String roomId)? onCallAccepted;
  Function()? onCallRejected;
  Function(RTCSessionDescription)? onRemoteDescription;
  Function(RTCIceCandidate)? onRemoteIceCandidate;

  void initialize(String userToken) {
    if (_isInitialized) return; // 🔐 Prevent double initialization

    token = userToken;
    _isInitialized = true;
    connect();
  }


  void connect() {
    final uri = Uri.parse('ws://192.168.1.53:8000/ws/send_call_request?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel.stream.listen((event) {
      final data = jsonDecode(event);

      switch (data['event']) {
        case 'incoming_call':
          final fromName = data['from_user']['name'];
          final fromId = data['from_user']['id']; // ✅ Get caller's ID
          final roomId = data['room_id'];
          onIncomingCall?.call(roomId, fromName, fromId); // ✅ Pass caller ID
          break;

        case 'call_accepted':
          onCallAccepted?.call(data['room_id']);
          break;

        case 'answer':
          final description = RTCSessionDescription(
            data['description']['sdp'],
            data['description']['type'],
          );
          onRemoteDescription?.call(description);
          break;

        case 'call_rejected':
          onCallRejected?.call();
          break;

        case 'remote_description':
          final description = RTCSessionDescription(
            data['description']['sdp'],
            data['description']['type'],
          );
          onRemoteDescription?.call(description);
          break;

        case 'ice_candidate':
          final candidate = RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          );
          onRemoteIceCandidate?.call(candidate);
          break;
      }
    });
  }

  void callUser(int calleeId) {
    _channel.sink.add(jsonEncode({
      'event': 'call_user',
      'callee_id': calleeId,
    }));
  }

  void respondToCall({required bool accepted, required String roomId}) {
    _channel.sink.add(jsonEncode({
      'event': 'call_response',
      'accepted': accepted,
      'room_id': roomId,
    }));
  }

  void sendAnswer(String roomId, RTCSessionDescription answer) {
    final message = {
      'event': 'answer',
      'room_id': roomId,
      'description': {
        'type': answer.type,
        'sdp': answer.sdp,
      }
    };
    _channel.sink.add(jsonEncode(message));
  }


  void disconnect() {
    _channel.sink.close();
    _isInitialized = false; // Reset so we can reinit later
  }


  void sendIceCandidate(RTCIceCandidate candidate, String roomId) {
    final message = {
      'event': 'ice_candidate',
      'room_id': roomId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }
    };
    _channel.sink.add(jsonEncode(message));
  }

  Future<void> startVoiceChat(String roomId, RTCPeerConnection peerConnection) async {
    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);

    final message = {
      'event': 'start_voice_chat',
      'room_id': roomId,
      'description': {
        'type': offer.type,
        'sdp': offer.sdp,
      }
    };

    _channel.sink.add(jsonEncode(message));
  }


}
