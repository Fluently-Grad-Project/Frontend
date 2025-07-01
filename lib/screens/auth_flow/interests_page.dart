import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/onboarding_provider.dart';
import 'account_creation_page.dart';

class InterestsPage extends StatefulWidget {
  const InterestsPage({super.key});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage> {
  final List<String> allInterests = [
    "Art", "Beauty", "Books", "Business and entrepreneurship", "Cars and automobiles",
    "Cooking", "DIY and crafts", "Education and learning", "Fashion", "Finance and investments",
    "Fitness", "Food and dining", "Gaming", "Gardening", "Health and wellness", "History",
    "Movies", "Music", "Nature", "Outdoor activities", "Parenting and family", "Pets",
    "Photography", "Politics", "Science", "Social causes and activism", "Sports",
    "Technology", "Travel",
  ];

  final Set<String> selectedInterests = {};

  void goToNextPage() {
    Provider.of<OnboardingProvider>(context, listen: false)
        .data
        .interests = selectedInterests.toList();

    final firstName = Provider.of<OnboardingProvider>(context, listen: false).data.firstName ?? "User";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountCreatedPage(firstName: firstName),
      ),
    );
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
              children: [
                _buildProgressBar(1.0),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedInterests.isNotEmpty ? goToNextPage : null,
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
      backgroundColor: const Color(0xFF9F86C0),
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      shape: const StadiumBorder(
        side: BorderSide(color: Color(0xFF9F86C0), width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }
}
