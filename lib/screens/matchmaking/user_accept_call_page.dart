import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'after_call_page.dart';
import 'user_making_call_page.dart';

class UserAcceptCallPage extends StatelessWidget {
  final int userId;
  final String userName;

  const UserAcceptCallPage({Key? key, required this.userId, required this.userName}) : super(key: key);

  static const double headerHeight = 60.0;

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
                    userName,
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
            GestureDetector(
              onTap: () async {
                if (await Vibration.hasVibrator() ?? false) {
                  Vibration.vibrate(duration: 200);
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AfterCallPage(userId: userId),
                  ),
                );
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
