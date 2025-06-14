import 'package:fluently_frontend/screens/user_accept_call_page.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';




class UserChatRequestPage extends StatefulWidget {
  const UserChatRequestPage({Key? key}) : super(key: key);

  @override
  State<UserChatRequestPage> createState() => _UserChatRequestPageState();
}

class _UserChatRequestPageState extends State<UserChatRequestPage> {
  double _acceptScale = 1.0;
  double _declineScale = 1.0;
  late AudioPlayer _audioPlayer;
  late Timer _autoDismissTimer;


  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playRingtone();
    _startAutoDismissTimer();

    // Keep the screen on
    WakelockPlus.enable();
  }

  void _startAutoDismissTimer() {
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        _stopRingtone();
        Vibration.cancel();
        Navigator.pop(context);
      }
    });
  }

  void _playRingtone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('iphone_ringtone.mp3'));

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 1000],
          repeat: 0); // Vibrate pattern: vibrate 500ms, pause 1000ms, repeat
    }
  }

  void _stopRingtone() async {
    await _audioPlayer.stop();
    Vibration.cancel(); // Stop vibration
  }

  void _animateButton(Function action, bool isAccept) {
    _stopRingtone(); // stop ringtone on any action
    _autoDismissTimer.cancel(); // cancel auto dismiss
    setState(() {
      if (isAccept) {
        _acceptScale = 0.9;
      } else {
        _declineScale = 0.9;
      }
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _acceptScale = 1.0;
        _declineScale = 1.0;
      });
      action();
    });
  }

  @override
  void dispose() {
    _stopRingtone();
    _autoDismissTimer.cancel();
    _audioPlayer.dispose();

    // Allow screen to sleep again
    WakelockPlus.disable();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDECEE),
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text(
                'Chat request',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                ),
              ),
              backgroundColor: Colors.white,
              toolbarHeight: 60,
              elevation: 2,
              centerTitle: false,
            ),
            const SizedBox(height: 20),
            const Text(
              "You have a new chat request",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Image.asset(
                          'assets/caller-icon.png',
                          width: 130,
                          height: 130,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Bassant",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 220),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Decline Button with Glow
                        _buildGlowingButton(
                          iconPath: 'assets/decline-icon.png',
                          onTap: () =>
                              _animateButton(() => Navigator.pop(context),
                                  false),
                          scale: _declineScale,
                          glowColor: Colors.redAccent,
                        ),
                        const SizedBox(width: 135),
                        // Accept Button with Glow
                        _buildGlowingButton(
                          iconPath: 'assets/accept-icon.png',
                          onTap: () =>
                              _animateButton(() {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (
                                      context) => const UserAcceptCallPage()),
                                );
                              }, true),
                          scale: _acceptScale,
                          glowColor: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingButton({
    required String iconPath,
    required VoidCallback onTap,
    required double scale,
    required Color glowColor,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 4.0),
      // Reduced blur
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, radius, child) {
        return AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 100),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.15), // Dimmer opacity
                    blurRadius: radius,
                    spreadRadius: 0.3, // Smaller spread
                  ),
                ],
              ),
              child: Image.asset(
                iconPath,
                width: 80,
                height: 80,
              ),
            ),
          ),
        );
      },
      onEnd: () => setState(() {}), // Loop animation
    );
  }
}