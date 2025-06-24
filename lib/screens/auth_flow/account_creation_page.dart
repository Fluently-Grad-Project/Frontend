import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(onboardingData.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success! Navigate to home
        if (mounted) {
          Navigator.pushNamed(context, '/home');
        }
      } else {
        setState(() {
          _errorMessage = 'Registration failed: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
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