import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'InCallScreen.dart';

class VoiceCallService {
  static Future<void> answerCall({
    required Map<String, dynamic> offerData,
    required BuildContext context,
  }) async {
    final _firestore = FirebaseFirestore.instance;
    final _remoteRenderer = RTCVideoRenderer();
    final _localRenderer = RTCVideoRenderer();
    final _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    final localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    for (var track in localStream.getAudioTracks()) {
      _peerConnection.addTrack(track, localStream);
    }

    final offer = RTCSessionDescription(offerData['sdp'], offerData['sdpType']);
    await _peerConnection.setRemoteDescription(offer);
    final answer = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(answer);

    await _firestore.collection('calls').doc(offerData['docId']).update({
      'type': 'answer',
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InCallScreen(
          hangUp: () async {
            await _peerConnection.close();
            await _peerConnection.dispose();
            await localStream.dispose();
            await _remoteRenderer.dispose();
            await _localRenderer.dispose();
            await _firestore.collection('calls').doc(offerData['docId']).update({
              'callEnded': true,
            });
          },
          selfId: offerData['calleeId'],
        ),
      ),
    );
  }
}
