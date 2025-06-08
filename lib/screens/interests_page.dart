import 'package:flutter/material.dart';
import 'account_creation_page.dart';

class InterestsPage extends StatefulWidget {
  final String firstName;
  final String selectedLanguage;
  final String proficiencyLevel;
  final String practiceFrequency;

  const InterestsPage({
    super.key,
    required this.firstName,
    required this.selectedLanguage,
    required this.proficiencyLevel,
    required this.practiceFrequency,
  });

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  final List<String> allInterests = [
    "Movies",
    "Music",
    "Sports",
    "Books",
    "Travel",
    "Technology",
    "Cooking",
    "Gaming",
    "Art",
    "Reading",
    "Self-care",
    "Fashion",
    "Animals",
    "Podcasts",
    "Shopping",
    "Fitness",
    "Food",
  ];

  final Set<String> selectedInterests = {};

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
                _buildProgressBar(1.0),
                const SizedBox(height: 24),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                const Text(
                  "What are your interests?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: allInterests.map(_buildChip).toList(),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedInterests.isNotEmpty
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccountCreatedPage(
                            firstName: widget.firstName,
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

  Widget _buildChip(String label) {
    final isSelected = selectedInterests.contains(label);

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF9F86C0),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            selectedInterests.add(label);
          } else {
            selectedInterests.remove(label);
          }
        });
      },
      selectedColor: const Color(0xFF9F86C0),
      backgroundColor: Colors.white,
      shadowColor: Colors.grey.shade300,
      elevation: 4,
      pressElevation: 0,
      shape: StadiumBorder(
        side: BorderSide(color: const Color(0xFF9F86C0), width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }
}
