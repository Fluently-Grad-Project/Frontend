import 'dart:async';

import 'package:besso_fluently/screens/matchmaking/user_accept_call_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

class UserMakingCallPage extends StatefulWidget {
  final String callDocId;
  final String selfId;
  final Future<void> Function() hangUp;
  final VoidCallback onCallAnswered;
  final String userName;

  const UserMakingCallPage({
    Key? key,
    required this.callDocId,
    required this.selfId,
    required this.hangUp,
    required this.onCallAnswered,
    required this.userName,
  }) : super(key: key);


  @override
  State<UserMakingCallPage> createState() => _UserMakingCallPageState();
}

class _UserMakingCallPageState extends State<UserMakingCallPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<DocumentSnapshot>? _callSub;


  @override
  void initState() {
    super.initState();
    _playCallingSound();
    _listenCallChanges();
  }

  void _listenCallChanges() {
    final docRef = FirebaseFirestore.instance.collection('calls').doc(widget.callDocId);
    _callSub = docRef.snapshots().listen((doc) async {
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      if (data['callEnded'] == true) {
        // Call ended (rejected or cancelled)
        await widget.hangUp();
        if (mounted) Navigator.of(context).pop(); // go back to caller page
      } else if (data['type'] == 'answer') {
        // Call accepted
        widget.onCallAnswered();
      }
    });
  }

  Future<void> _playCallingSound() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); // loop the sound
    await _audioPlayer.play(AssetSource('phone-calling.mp3'));
  }

  @override
  void dispose() {
    _audioPlayer.stop(); // stop sound when page is disposed
    _audioPlayer.dispose();
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 60.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Calling...',
          style: TextStyle(fontSize: 18, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: const Color(0xFFEDECEE),
        width: double.infinity,
        child: Column(
          children: [
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Calling ${widget.userName}...',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Ringing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Transform.translate(
              offset: const Offset(0, -50),
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Lottie.asset(
                  'assets/animations/calling.json',
                  repeat: true,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                if (await Vibration.hasVibrator() ?? false) {
                  Vibration.vibrate(duration: 200);
                }
                await widget.hangUp(); // ✅ Ensure full cleanup
                if (mounted) Navigator.of(context).pop(); // ⬅ Then pop the page
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