
import 'package:flutter/material.dart';
import 'proficiency_level_page.dart';

class LanguageSelectionPage extends StatefulWidget {
  final String firstName;

  const LanguageSelectionPage({super.key, required this.firstName});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String selectedLanguage = '';

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
                _buildProgressBar(0.25),
                const SizedBox(height: 24),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Which language do you want to practice?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                _buildLanguageOption("English"),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedLanguage.isNotEmpty
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProficiencyLevelPage(
                            firstName: widget.firstName,
                            selectedLanguage: selectedLanguage,
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
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      minHeight: 6,
    );
  }

  Widget _buildLanguageOption(String language) {
    final isSelected = selectedLanguage == language;

    return GestureDetector(
      onTap: () => setState(() => selectedLanguage = language),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9F86C0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9F86C0), width: 2),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/uk-flag-icon.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Center(
                child: Text(
                  language,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF9F86C0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40), // To balance the flag on the left
          ],
        ),
      ),
    );
  }

}
