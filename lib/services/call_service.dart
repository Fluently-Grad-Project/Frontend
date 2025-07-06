import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/matchmaking/user_chat_request_page.dart';

class CallService {
  static final CallService _instance = CallService._internal();

  factory CallService() => _instance;

  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _callListener;

  bool _initialized = false;

  void setupCallListener({
    required BuildContext context,
    required String selfId,
    required Future<void> Function(Map<String, dynamic> offerData) onAnswerCall,
  }) {
    if (_initialized) return;
    _initialized = true;

    _callListener = _firestore
        .collection('calls')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['calleeId'] == selfId && data['type'] == 'offer') {
          final callerId = data['callerId'];
          String callerName = "Unknown";

          try {
            final userDoc = await _firestore.collection('users').doc(callerId).get();
            if (userDoc.exists) {
              callerName = userDoc.data()?['username'] ?? "Unknown";
            }
          } catch (_) {}

          if (!context.mounted) return;

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserChatRequestPage(
                callerId: callerId,
                callerName: callerName,
                firebaseUid: selfId,
                offerData: {...data, 'docId': doc.id},
              ),
            ),
          );

          if (result == true) {
            await onAnswerCall({...data, 'docId': doc.id});
          }
        }
      }
    });
  }

  void dispose() {
    _callListener?.cancel();
    _callListener = null;
    _initialized = false;
  }
}