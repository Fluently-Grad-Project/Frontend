import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';  // Make sure you have flutter_webrtc imported

class InCallScreen extends StatefulWidget {
  final Future<void> Function() hangUp;
  final String selfId;

  const InCallScreen({
    super.key,
    required this.hangUp,
    required this.selfId,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _callSub;
  String? _callDocId;
  String? _otherUserId;
  String _otherUserName = 'Voice Chat';

  static const double headerHeight = 60.0;

  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    listenToCallEnd();
  }

  Future<void> listenToCallEnd() async {
    // find the active call where self is either caller or callee
    final query = await _firestore
        .collection('calls')
        .where('callEnded', isEqualTo: false)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      if (data['callerId'] == widget.selfId || data['calleeId'] == widget.selfId) {
        _callDocId = doc.id;
        _callSub = _firestore
            .collection('calls')
            .doc(_callDocId)
            .snapshots()
            .listen((snapshot) async {
          final callData = snapshot.data();
          if (callData != null && callData['callEnded'] == true) {
            print("📴 Remote user ended call");
            await widget.hangUp();
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
        break;
      }
    }
  }

  Future<void> _fetchOtherUserName() async {
    if (_otherUserId == null) {
      print("No other user ID found");
      return;
    }
    print("Fetching username for user id: $_otherUserId");

    final query = await _firestore
        .collection('users')
        .where('uid', isEqualTo: _otherUserId)
        .limit(1)
        .get();

    print("User query returned docs: ${query.docs.length}");
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      print("User document data: $data");
      final username = data['username'] ?? '';
      setState(() {
        _otherUserName = username.isNotEmpty ? username : 'Unknown User';
      });
    } else {
      print("No user found with uid=$_otherUserId");
      setState(() {
        _otherUserName = 'Unknown User';
      });
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  double topSpacingHeight = 35.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'User Call',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),
      body: Container(
        color: const Color(0xFFEDECEE),
        width: double.infinity,
        child: Column(
          children: [
            // Header bar with user info
            Container(
              width: double.infinity,
              height: headerHeight,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x6E9F86C0),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/caller-icon.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Big centered call AI icon, moved upward
            Transform.translate(
              offset: const Offset(0, -50),
              child: Center(
                child: Image.asset(
                  'assets/call-ai-icon.png',
                  width: 290,
                  height: 290,
                ),
              ),
            ),

            // End call button below the big icon
            GestureDetector(
              onTap: () async {
                await widget.hangUp();
                if (mounted) Navigator.of(context).popUntil((route) =>
                route.isFirst);
              },
              child: Center(
                child: Image.asset(
                  'assets/end-call-icon.png',
                  width: 130,
                  height: 130,
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
