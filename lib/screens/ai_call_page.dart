import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import 'ai_chat_page.dart';

class AICallPage extends StatelessWidget {
  const AICallPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'AI Call',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 30.0, bottom: 20.0),
              child: Center(
                child: Text(
                  'You can speak Now. I am listening !',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Spacer(),
            Transform.translate(
              offset: const Offset(0, -50),
              child: Image.asset(
                'assets/call-ai-icon.png',
                width: 290,
                height: 290,
              ),
            ),
            GestureDetector(
              onTap: () async {
                if (await Vibration.hasVibrator() ?? false) {
                  Vibration.vibrate(duration: 200);
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AIChatPage()),
                );
              },
              child: Image.asset(
                'assets/end-call-icon.png',
                width: 130,
                height: 130,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
