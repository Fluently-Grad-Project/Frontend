import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart'; // If you use Dio for API calls
import 'package:shared_preferences/shared_preferences.dart';

// TODO: Adjust these import paths to match your project structure
import '../../providers/onboarding_provider.dart';

// TODO: Replace with your actual JWT token or a secure way to access it for API calls
// It's better to get this from the OnboardingProvider if it's stored there after login.
const String YOUR_JWT_TOKEN = "YOUR_JWT_TOKEN_PLACEHOLDER";

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  int _selectedIndex = 4; // Default to Account tab

  // Example: If you have a predefined list of interests for the edit dialog
  final List<String> _allAvailableInterests = [
    'Reading', 'Sports', 'Music', 'Movies', 'Traveling', 'Cooking', 'Gaming',
    'Art', 'Photography', 'Writing', 'Dancing', 'Fitness', 'Yoga', 'Meditation',
    'Technology', 'Science', 'History', 'Politics', 'Volunteering', 'Learning Languages'
  ];

  final Dio _dio = Dio(); // Initialize Dio if used for API calls in this file

  @override
  Widget build(BuildContext context) {

    return Consumer<OnboardingProvider>(
      builder: (context, onboardingProvider, child) {
        final OnboardingData currentUserData = onboardingProvider.data;

        // Basic check: If there's no user ID and no access token,
        // it might mean the user isn't logged in or data hasn't loaded.
        // You might want a more robust loading state or check here.
        if (currentUserData.id == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Profile")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("You are not logged in or user data is unavailable."),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text("Go to Login"),
                  )
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomNavigationBar(), // Keep consistent UI
          );
        }

        // Prepare data for _buildBody, providing defaults for null values
        String imageUrl = currentUserData.profileImage ?? "";
        String displayName = "${currentUserData.firstName ?? ''} ${currentUserData.lastName ?? ''}".trim();
        if (displayName.isEmpty) {
          displayName = currentUserData.email ?? "User"; // Fallback to email or generic "User"
        }
        //int userAge = currentUserData.age ?? 0; // Assuming 'age' getter in OnboardingData
        List<String> interests = currentUserData.interests ?? [];

        return Scaffold(
          body: _buildBody(
            context,
            imageUrl,
            displayName,
           // userAge,
            interests,
            onboardingProvider, // Pass the provider for the edit dialog
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.group_outlined), activeIcon: Icon(Icons.group), label: 'Friends'),
        BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), activeIcon: Icon(Icons.forum), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline), activeIcon: Icon(Icons.lightbulb), label: 'AI Coach'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), activeIcon: Icon(Icons.account_circle), label: 'Account'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: false,
      showSelectedLabels: false,
    );
  }

  Widget _buildBody(
      BuildContext context,
      String imageUrl,
      String displayName,

      List<String> interests,
      OnboardingProvider onboardingProvider, // Receive the provider
      ) {
    String interestsDisplayString = interests.isNotEmpty ? interests.join(', ') : "No interests set";
    const Color headerColor = Color(0xFFA58DCA);

    return Column(
      children: [
        Container(
          color: Colors.white, // Or Theme.of(context).appBarTheme.backgroundColor
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(icon: Icon(Icons.arrow_back_ios_new, color: headerColor), onPressed: () => Navigator.pop(context))
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      "My Profile",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the leading widget
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white, // Or Theme.of(context).scaffoldBackgroundColor
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView( // Added SingleChildScrollView for longer content
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty ? Icon(Icons.person, size: 60, color: Colors.grey.shade700) : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  //Text(
                  //  userAge > 0 ? 'Age: $userAge' : 'Age: Not specified',
                  //  style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                  //  textAlign: TextAlign.center,
                  //),
                  const SizedBox(height: 20),
                  Text(
                    "Interests:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  if (interests.isNotEmpty)
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      alignment: WrapAlignment.center,
                      children: interests.map((interest) => Chip(
                        label: Text(interest),
                        backgroundColor: headerColor.withOpacity(0.1),
                        labelStyle: TextStyle(color: headerColor.withOpacity(0.8)),
                      )).toList(),
                    )
                  else
                    Text(
                      "No interests set yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showEditProfileDialog(context, onboardingProvider),
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: headerColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _logoutApiCall(context),
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text("Logout", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext pageContext, OnboardingProvider onboardingProvider) {
    final OnboardingData currentUser = onboardingProvider.data;

    final firstNameController = TextEditingController(text: currentUser.firstName);
    final lastNameController = TextEditingController(text: currentUser.lastName);
    // Assuming gender is stored as a string like "male", "female", "other", or "prefer_not_to_say"
    String? selectedGender = currentUser.gender;
    final Set<String> selectedInterests = Set<String>.from(currentUser.interests ?? []);

    showDialog(
      context: pageContext, // Use pageContext from the builder
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Use StatefulBuilder for state within the dialog
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'First Name')),
                    TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Last Name')),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Gender'),
                      value: selectedGender,
                      items: ['male', 'female', 'other', 'prefer_not_to_say'] // API values
                          .map((label) => DropdownMenuItem(value: label, child: Text(label.replaceAll('_', ' ').capitalizeFirst()))).toList(),
                      onChanged: (value) => setDialogState(() => selectedGender = value),
                    ),
                    const SizedBox(height: 16),
                    const Text("Interests:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 5.0,
                      children: _allAvailableInterests.map((interest) {
                        return FilterChip(
                          label: Text(interest),
                          selected: selectedInterests.contains(interest),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedInterests.add(interest);
                              } else {
                                selectedInterests.remove(interest);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final Map<String, dynamic> updatedData = {
                      if (firstNameController.text.isNotEmpty) 'first_name': firstNameController.text,
                      if (lastNameController.text.isNotEmpty) 'last_name': lastNameController.text,
                      if (selectedGender != null) 'gender': selectedGender,
                      'interests': selectedInterests.toList(),
                      // Add other fields like birthDate if you have them
                    };
                    // Ensure that fields that shouldn't be empty or are required by the API are handled.
                    Navigator.of(dialogContext).pop(); // Close dialog first
                    _updateProfileApiCall(updatedData, pageContext, onboardingProvider);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateProfileApiCall(Map<String, dynamic> data, BuildContext pageContext, OnboardingProvider provider) async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    final onboardingProvider = Provider.of<OnboardingProvider>(context);
    final String? userId = onboardingProvider.data.id?.toString();
    final String? token = prefs.getString("token"); // Get token from provider

    if (userId == null || token == null) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('User not identified. Cannot update profile.'), backgroundColor: Colors.red),
      );
      return;
    }

    // TODO: Replace with your actual API endpoint and Dio call
    const String updateProfileApiUrl = "http://10.0.2.2:8000/users/update-profile/"; // Ensure this is correct

    // TODO: Implement actual API call logic (e.g., using Dio)
    // Example (pseudo-code):
    // try {
    //   final response = await _dio.patch(
    //     updateProfileApiUrl + userId, // Assuming API expects user ID in URL
    //     data: data,
    //     options: Options(headers: {'Authorization': 'Bearer $token'}),
    //   );
    //   if (response.statusCode == 200) {
    //     ScaffoldMessenger.of(pageContext).showSnackBar(
    //       const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
    //     );
    //     // *** IMPORTANT: Update the OnboardingProvider with the new data from response ***
    //     // provider.updateUserDataFromMap(response.data); // Assuming you have such a method
    //   } else {
    //     ScaffoldMessenger.of(pageContext).showSnackBar(
    //       SnackBar(content: Text('Failed to update profile: ${response.statusCode}'), backgroundColor: Colors.red),
    //     );
    //   }
    // } catch (e) {
    //   ScaffoldMessenger.of(pageContext).showSnackBar(
    //     SnackBar(content: Text('An error occurred: ${e.toString()}'), backgroundColor: Colors.red),
    //   );
    // }

    // Placeholder for now, remove once API call is implemented
    print("Simulating API call to update profile with data: $data for user $userId with token $token");
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(content: Text('Profile update simulation. Implement actual API call.'), backgroundColor: Colors.orange),
    );
    // Remember to update the provider after a real successful API call
    // provider.updateUserDataFromMap(updatedDataFromApi);
  }

  Future<void> _logoutApiCall(BuildContext context) async {
    // TODO: Implement your actual logout API call
    // Example (pseudo-code):
    // try {
    //   final response = await _dio.post(
    //     "YOUR_LOGOUT_API_ENDPOINT",
    //     options: Options(headers: {'Authorization': 'Bearer YOUR_JWT_TOKEN_FROM_PROVIDER'}),
    //   );
    //   if (response.statusCode == 200 || response.statusCode == 204) {
    //     Provider.of<OnboardingProvider>(context, listen: false).clear(); // Clear provider data
    //     Navigator.pushReplacementNamed(context, '/login');
    //   } else {
    //     // Handle logout error
    //   }
    // } catch (e) {
    //   // Handle exception
    // }

    // Placeholder for now
    print("Simulating logout API call.");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logout simulation. Implement actual API call.'), backgroundColor: Colors.orange),
    );
    // For now, just clear provider and navigate (remove this part once API call is real)
    Provider.of<OnboardingProvider>(context, listen: false).clearAll();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Do nothing if the same tab is tapped

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/friends');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/ai_coach'); // Or your actual route for AI Coach
        break;
      case 4:
      // Already on the profile page, no navigation needed, just ensure the index is set.
        break;
    }
  }
}

// Helper extension (if you used it for gender capitalization in the dialog, keep it or place it appropriately)
extension StringExtension on String {
  String capitalizeFirst() {
    if (this.isEmpty) {
      return this;
    }
    return this[0].toUpperCase() + this.substring(1).toLowerCase();
  }
}