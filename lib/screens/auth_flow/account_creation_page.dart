import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 Firestore import

import '../../../providers/onboarding_provider.dart';

class AccountCreatedPage extends StatefulWidget {
  final String firstName;

  const AccountCreatedPage({super.key, required this.firstName});

  @override
  State<AccountCreatedPage> createState() => _AccountCreatedPageState();
}

class _AccountCreatedPageState extends State<AccountCreatedPage> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final onboardingData = Provider.of<OnboardingProvider>(
        context,
        listen: false,
      ).data;

      if (onboardingData.email == null || onboardingData.password == null) {
        setState(() {
          _errorMessage = 'Email and password are required.';
          _isLoading = false;
        });
        return;
      }

      // Step 1: Firebase signup
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: onboardingData.email!,
        password: onboardingData.password!,
      );

      final firebaseUid = userCredential.user?.uid;
      if (firebaseUid == null) {
        throw Exception("Firebase UID is null");
      }

      // Step 2: Prepare payload for backend
      final userPayload = onboardingData.toJson();
      userPayload['firebase_uid'] = firebaseUid;

      // Step 3: Send to backend
      final response = await http.post(
        Uri.parse('http://192.168.1.53:8000/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userPayload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final userId = responseData['user']?['id'];

        // ✅ Step 4: Store in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUid)
            .set({
          'uid': firebaseUid,
          'email': onboardingData.email,
          'user_id': userId,
          'first_name': onboardingData.firstName,
          'last_name': onboardingData.lastName,
          'username': "${onboardingData.firstName} ${onboardingData.lastName}".trim(),
        });


        if (mounted) {
          Navigator.pushNamed(context, '/login');
        }
      } else {
        setState(() {
          _errorMessage = 'Registration failed: ${response.body}';
        });
      }
    } catch (e) {
      String message = 'Error: ${e.toString()}';
      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          message = 'Email is already registered.';
        } else if (e.code == 'weak-password') {
          message = 'The password is too weak.';
        }
      }

      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9F86C0), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.white)
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              )
            else ...[
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.check,
                    size: 60,
                    color: Color(0xFF9C6BCE),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Hey ${widget.firstName} 👋!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Account created successfully',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9F86C0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
