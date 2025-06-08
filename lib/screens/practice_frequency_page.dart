import 'package:flutter/material.dart';
import 'interests_page.dart';

class PracticingFrequencyPage extends StatefulWidget {
  final String firstName;
  final String selectedLanguage;
  final String proficiencyLevel;

  const PracticingFrequencyPage({
    super.key,
    required this.firstName,
    required this.selectedLanguage,
    required this.proficiencyLevel,
  });

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
                  "How often would you like to practice?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                ...options.map((option) => _buildOption(
                  option,
                  selectedFrequency,
                      (val) => setState(() => selectedFrequency = val),
                )),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedFrequency.isNotEmpty
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InterestsPage(
                            firstName: widget.firstName,
                            selectedLanguage: widget.selectedLanguage,
                            proficiencyLevel: widget.proficiencyLevel,
                            practiceFrequency: selectedFrequency,
                          ),
                        ),
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9F86C0),
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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
      backgroundColor: Colors.white,
      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9F86C0)),
      minHeight: 6,
    );
  }

  Widget _buildOption(String label, String selected, void Function(String) onSelect) {
    final isSelected = selected == label;

    return GestureDetector(
      onTap: () => onSelect(label),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9F86C0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9F86C0), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF9F86C0),
            ),
          ),
        ),
      ),
    );
  }
}
