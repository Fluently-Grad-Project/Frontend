import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';
import 'interests_page.dart';

class PracticingFrequencyPage extends StatefulWidget {
  const PracticingFrequencyPage({super.key});

  @override
  State<PracticingFrequencyPage> createState() => _PracticingFrequencyPageState();
}

class _PracticingFrequencyPageState extends State<PracticingFrequencyPage> {
  String selectedFrequency = '';

  final List<String> options = [
    '15 minutes/day',
    '30 minutes/day',
    '1 hour/day',
    '2 hours/day',
  ];

  void goToNextPage() {
    if (selectedFrequency.isNotEmpty) {
      Provider.of<OnboardingProvider>(context, listen: false)
          .data
          .practiceFrequency = selectedFrequency;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const InterestsPage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a practice frequency.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9F86C0), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressBar(0.75),
                const SizedBox(height: 24),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                const Text(
                  "How much time can you practice daily?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                ...options.map((option) => _buildOption(option)).toList(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: goToNextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9F86C0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: const Color(0xFF9F86C0),
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      minHeight: 6,
    );
  }

  Widget _buildOption(String text) {
    final isSelected = selectedFrequency == text;

    return GestureDetector(
      onTap: () => setState(() => selectedFrequency = text),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9F86C0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9F86C0), width: 2),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF9F86C0),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
