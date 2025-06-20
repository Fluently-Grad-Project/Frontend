import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth_flow/splash_page.dart';
import 'screens/auth_flow/signup_page.dart';
import 'screens/auth_flow/login_page.dart';
import 'screens/auth_flow/language_selection_page.dart';
import 'screens/auth_flow/proficiency_level_page.dart';
import 'screens/auth_flow/practice_frequency_page.dart';
import 'screens/auth_flow/interests_page.dart';
import 'screens/auth_flow/account_creation_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fluently',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignUpPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}
