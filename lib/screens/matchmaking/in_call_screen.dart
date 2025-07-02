import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class InCallScreen extends StatefulWidget {
  final Future<void> Function() hangUp;
  final String selfId;
  final String? calleeName;
  final int? calleeUserId;

  const InCallScreen({
    super.key,
    required this.hangUp,
    required this.selfId,
    this.calleeName,
    this.calleeUserId,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _callSub;
  String? _callDocId;

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

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.calleeName != null ? 'Calling ${widget.calleeName}' : 'In Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end),
            color: Colors.red,
            onPressed: () async {
              await widget.hangUp();
              if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: const Center(
        child: Text("In Call..."),
      ),
    );
  }
}

