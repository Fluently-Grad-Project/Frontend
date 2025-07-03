import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

typedef OnIncomingCall = void Function(Map<String, dynamic> callData);
typedef OnCallEnded = void Function();

class CallManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _callSub;
  StreamSubscription<DocumentSnapshot>? _callStateSub;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  String? _callDocId;

  bool _isListening = false;

  // Start listening for incoming calls and notify via callback
  void startListening({required OnIncomingCall onIncomingCall}) {
    if (_isListening) return;
    _isListening = true;

    final selfId = _auth.currentUser?.uid;
    if (selfId == null) return;

    _callSub = _firestore
        .collection('calls')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['calleeId'] == selfId && data['type'] == 'offer') {
          final callData = Map<String, dynamic>.from(data);
          callData['docId'] = doc.id;
          _callDocId = doc.id;
          onIncomingCall(callData);
          break;
        }
      }
    });
  }

  // Stop listening for incoming calls
  void stopListening() {
    _callSub?.cancel();
    _callSub = null;
    _isListening = false;
  }

  // Answer the call (simplified version)
  Future<void> answerCall(Map<String, dynamic> offerData) async {
    final selfId = _auth.currentUser?.uid;
    if (selfId == null) return;

    if (_callDocId != null && _callDocId != offerData['docId']) {
      // Clean up old call if different
      await hangUp();
    }

    _callDocId = offerData['docId'];

    if (selfId == offerData['callerId']) {
      print("Caller and callee are same UID. Ignoring call.");
      return;
    }

    await _resetMediaState();

    await _initLocalStream();

    _peerConnection = await _createPeerConnection(isCaller: false);

    // Add local tracks
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }
    }

    final offer = RTCSessionDescription(offerData['sdp'], offerData['sdpType']);
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _firestore.collection('calls').doc(_callDocId).update({
      'type': 'answer',
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });

    _listenForRemoteIceCandidates(isCaller: false);

    // Listen for call ended
    _callStateSub?.cancel();
    _callStateSub = _firestore.collection('calls').doc(_callDocId!).snapshots().listen((docSnapshot) async {
      final data = docSnapshot.data();
      if (data == null) return;

      if (data['callEnded'] == true) {
        await hangUp();
      }
    });
  }

  Future<void> _resetMediaState() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
      await _peerConnection!.dispose();
      _peerConnection = null;
    }
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
  }

  Future<void> _initLocalStream() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      print('Microphone permission not granted');
      return;
    }
    final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream = stream;
  }

  Future<RTCPeerConnection> _createPeerConnection({required bool isCaller}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final pc = await createPeerConnection(config);

    pc.onIceCandidate = (candidate) async {
      if (_callDocId != null) {
        final candidatesCollection = _firestore
            .collection('calls')
            .doc(_callDocId)
            .collection(isCaller ? 'callerCandidates' : 'calleeCandidates');
        await candidatesCollection.add(candidate.toMap());
      }
    };

    return pc;
  }

  void _listenForRemoteIceCandidates({required bool isCaller}) {
    final candidatesCollection = _firestore
        .collection('calls')
        .doc(_callDocId)
        .collection(isCaller ? 'calleeCandidates' : 'callerCandidates');

    candidatesCollection.snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );
            _peerConnection?.addCandidate(candidate);
          }
        }
      }
    });
  }

  // Hang up the call and clean up
  Future<void> hangUp() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
      await _peerConnection!.dispose();
      _peerConnection = null;
    }

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    if (_callDocId != null) {
      final docRef = _firestore.collection('calls').doc(_callDocId);
      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data()?['callEnded'] != true) {
        await docRef.update({'callEnded': true});
      }

      final callerCandidates = await docRef.collection('callerCandidates').get();
      for (var doc in callerCandidates.docs) {
        await doc.reference.delete();
      }
      final calleeCandidates = await docRef.collection('calleeCandidates').get();
      for (var doc in calleeCandidates.docs) {
        await doc.reference.delete();
      }

      _callDocId = null;
    }
  }
}
