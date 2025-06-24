import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/onboarding_provider.dart';

import 'screens/auth_flow/splash_page.dart';
import 'screens/auth_flow/signup_page.dart';
import 'screens/auth_flow/login_page.dart';
import 'screens/auth_flow/language_selection_page.dart';
import 'screens/auth_flow/proficiency_level_page.dart';
import 'screens/auth_flow/practice_frequency_page.dart';
import 'screens/auth_flow/interests_page.dart';
import 'screens/auth_flow/account_creation_page.dart';
import 'screens/home_page.dart';

import 'screens/auth_flow/forgot_password_page.dart';
import 'screens/auth_flow/rest_password.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fluently',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/signup': (context) => const SignUpPage(),
        '/login': (context) => const LoginPage(),
        '/language-selection': (context) => const LanguageSelectionPage(),
        '/proficiency-level': (context) => const ProficiencyLevelPage(),
        '/practice-frequency': (context) => const PracticingFrequencyPage(),
        '/interests': (context) => const InterestsPage(),
        '/account-created': (context) => const AccountCreatedPage(firstName: 'User'),
        '/home': (context) => const HomePage(),
        '/forgot-password': (context) =>  ForgotPasswordPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/reset-password') {
          final args = settings.arguments as Map<String, dynamic>;
          final email = args['email'] as String;
          return MaterialPageRoute(
            builder: (_) => ResetPasswordPage(email: email),
          );
        }
        return null;
      },
    );
  }
}
