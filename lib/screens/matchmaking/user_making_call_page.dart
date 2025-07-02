import 'package:besso_fluently/screens/matchmaking/user_accept_call_page.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

class UserMakingCallPage extends StatefulWidget {
  final int userId;
  final String userName;
  final String firebaseUid;

  const UserMakingCallPage({
    Key? key,
    required this.userId,
    required this.userName,
    required this.firebaseUid,
  }) : super(key: key);

  @override
  State<UserMakingCallPage> createState() => _UserMakingCallPageState();
}

class _UserMakingCallPageState extends State<UserMakingCallPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playCallingSound();

    // Simulate callee response after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;

      // Change this bool to true or false to test accept or decline
      bool calleeAccepted = true; // set false to test decline behavior

      if (calleeAccepted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserAcceptCallPage(
              userId: widget.userId,
              userName: widget.userName,
              firebaseUid: widget.firebaseUid,
            ),
          ),
        );
      } else {
        Navigator.pop(context); // Go back to MatchmakingPage on decline
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
                Navigator.of(context).pop();
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