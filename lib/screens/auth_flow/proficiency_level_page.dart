import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_provider.dart';
import 'practice_frequency_page.dart';

class ProficiencyLevelPage extends StatefulWidget {
  const ProficiencyLevelPage({super.key});

  @override
  State<ProficiencyLevelPage> createState() => _ProficiencyLevelPageState();
}

class _ProficiencyLevelPageState extends State<ProficiencyLevelPage> {
  String selectedLevel = '';

  void goToNextPage() {
    if (selectedLevel.isNotEmpty) {
      Provider.of<OnboardingProvider>(context, listen: false)
          .data
          .proficiencyLevel = selectedLevel;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PracticingFrequencyPage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your level.')),
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
                _buildProgressBar(0.50),
                const SizedBox(height: 24),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                const Text(
                  "What is your English proficiency level?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                _buildLevelOption("Beginner"),
                const SizedBox(height: 16),
                _buildLevelOption("Intermediate"),
                const SizedBox(height: 16),
                _buildLevelOption("Fluent"),
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

  Widget _buildLevelOption(String level) {
    final isSelected = selectedLevel == level;

    return GestureDetector(
      onTap: () => setState(() => selectedLevel = level),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9F86C0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9F86C0), width: 2),
        ),
        child: Text(
          level,
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
