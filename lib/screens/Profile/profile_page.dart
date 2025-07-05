import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/refresh_token_service.dart';

class MyProfilePage extends StatefulWidget {

  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  int _selectedIndex = 4;
  final Dio _dio = Dio();

  final List<String> allInterests = [
    "Art", "Beauty", "Books", "Business and entrepreneurship", "Cars and automobiles",
    "Cooking", "DIY and crafts", "Education and learning", "Fashion", "Finance and investments",
    "Fitness", "Food and dining", "Gaming", "Gardening", "Health and wellness", "History",
    "Movies", "Music", "Nature", "Outdoor activities", "Parenting and family", "Pets",
    "Photography", "Politics", "Science", "Social causes and activism", "Sports",
    "Technology", "Travel",
  ];



  Future<void> _showEditProfileDialog(BuildContext context) async {
    var userProvider = Provider.of<UserProvider>(context, listen: false) ;
    var user = userProvider.current;
    final TextEditingController firstNameController = TextEditingController(text: user!.firstName);
    final TextEditingController lastNameController = TextEditingController(text: user.lastName);
    String? selectedGender = user!.gender ?? 'GenderEnum.MALE';
    String? selectedProficiency = user.proficiency ?? 'BEGINNER';
    File? selectedImage;
    List<String> selectedInterests = List.from(user.interests ?? []);

    if (selectedGender == 'MALE' || selectedGender == 'GenderEnum.MALE' || selectedGender == 'male' || selectedGender == 'Male')  {
      selectedGender = 'Male';
    }
    else if (selectedGender == 'FEMALE' || selectedGender == 'GenderEnum.FEMALE' || selectedGender == 'female' || selectedGender == 'Female') {
      selectedGender = 'Female';
    }



    final List<String> genderOptions = ['Male', 'Female'];
    final List<String> proficiencyLevels = ['BEGINNER', 'INTERMEDIATE', 'FLUENT'];

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // isSaving state for the dialog's save button
        bool isDialogSaving = false;

        return StatefulBuilder( // For managing dialog-specific state like isDialogSaving
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: genderOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedGender = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedProficiency,
                      decoration: const InputDecoration(labelText: 'Proficiency Level'),
                      items: proficiencyLevels.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedProficiency = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text("Interests:"),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: allInterests.map((interest) {
                        final isSelected = selectedInterests.contains(interest);
                        return ChoiceChip(
                          label: Text(interest),
                          selected: isSelected,
                          onSelected: (selected) {
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
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Text("Profile Photo: "),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

                            if (pickedFile != null) {
                              setDialogState(() {
                                selectedImage = File(pickedFile.path);
                              });
                            }
                          },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text("Change"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          selectedImage!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
                // ... (your existing Column with TextFields, Dropdowns, ImagePicker, etc.) ...
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: isDialogSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
                  onPressed: isDialogSaving ? null : () async {
                    setDialogState(() {
                      isDialogSaving = true;
                    });

                    bool textDataUpdated = false;
                    bool imageUploaded = true; // Assume true if no image selected, or handle specific logic

                    final updatedUserData = {
                      'first_name': firstNameController.text,
                      'last_name': lastNameController.text,
                      'gender': selectedGender,
                      'interests': selectedInterests,
                      'proficiency_level': selectedProficiency,
                    };

                    // Call your API to update text data
                    // Ensure this function returns a bool indicating success
                    textDataUpdated = await _updateProfileApiCall(updatedUserData, context); // Pass the main page context

                    if (selectedImage != null && textDataUpdated) { // Optionally only upload image if text update was successful
                      // Ensure this function returns a bool indicating success
                      imageUploaded = await _uploadProfileImageApiCall(selectedImage!, context); // Pass the main page context
                    } else if (selectedImage != null && !textDataUpdated) {
                      print("ProfilePage: Text data update failed, skipping image upload.");
                      imageUploaded = false; // Or handle as a partial success/failure
                    }

                    setDialogState(() {
                      isDialogSaving = false;
                    });

                    if (textDataUpdated || imageUploaded) {
                      // --- THIS IS THE CRUCIAL PART ---
                      print("ProfilePage: Profile updates successful via API.");
                      userProvider.fetchById(user.id);

                      Navigator.of(dialogContext).pop(); // Close the dialog

                      // Optional: Show success SnackBar on the main page's context
                      // This was already present, but now it runs after provider updates
                      ScaffoldMessenger.of(context).showSnackBar( // Use original `context` for the page's ScaffoldMessenger
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );

                    } else {
                      print("ProfilePage: One or more profile update operations failed.");
                      // Keep the dialog open or show an error specific to the dialog context
                      ScaffoldMessenger.of(dialogContext).showSnackBar( // Use dialogContext here
                        const SnackBar(
                          content: Text('Failed to save all changes. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _uploadProfileImageApiCall(File imageFile, BuildContext pageContext) async {
    // Similar structure to _updateProfileApiCall, returning bool
    refreshToken(); // Consider making this await and checking success if it's critical before upload
    String uploadProfileImageApiUrl = "http://192.168.1.53:8000/users/upload-profile-picture";
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      final response = await _dio.post(
        uploadProfileImageApiUrl,
        data: FormData.fromMap({'file': await MultipartFile.fromFile(imageFile.path)}),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) { // Often 201 for creation/upload
        print("ProfilePage: _uploadProfileImageApiCall successful.");
        return true;
      } else if (response.statusCode == 401) {
        print("ProfilePage: _uploadProfileImageApiCall 401, attempting token refresh.");
        bool refreshed = await refreshToken();
        if (refreshed) {
          return await _uploadProfileImageApiCall(imageFile, pageContext); // Retry
        }
        return false;
      } else {
        print('ProfilePage: Error uploading profile image - Status: ${response.statusCode}');
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(content: Text('Image upload error: ${response.statusCode}'), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      print('ProfilePage: Error uploading profile image: $e');
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text('Image upload exception: ${e.toString()}'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  Future<bool> _updateProfileApiCall(Map<String, dynamic> data, BuildContext pageContext) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // No need to get UserProvider here if you're not using it directly for the API call itself
    // final currentUserProvider = Provider.of<UserProvider>(pageContext, listen: false);

    const String updateProfileApiUrl = "http://192.168.1.53:8000/users/update-profile";

    // Using pageContext for ScaffoldMessenger which is fine
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(content: Text('Updating profile...'), duration: Duration(milliseconds: 500)), // Shorter duration
    );

    try {
      final response = await _dio.patch(
        updateProfileApiUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );

      // No Future.delayed here, let the UI update when data is ready
      if (response.statusCode == 200) {
        print("ProfilePage: _updateProfileApiCall successful.");
        // The UserProvider.fetchById in the dialog's save handler will get the fresh data.
        // No need to update the provider from here directly if the dialog handles it.
        return true;
      } else if (response.statusCode == 401) {
        print("ProfilePage: _updateProfileApiCall 401, attempting token refresh.");
        bool refreshed = await refreshToken(); // Assuming refreshToken is accessible and returns bool
        if (refreshed) {
          return await _updateProfileApiCall(data, pageContext); // Retry
        }
        return false;
      } else {
        print("ProfilePage: _updateProfileApiCall failed. Status: ${response.statusCode}");
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(content: Text('Profile update error: ${response.statusCode}'), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      print("ProfilePage: _updateProfileApiCall error: $e");
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text("Name Can't be empty"), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    else if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/friends');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/chat');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/ai');
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/account');
    }
    print("FriendsPage: Navigating to index $index");
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logoutApiCall(BuildContext context) async {
    const String logoutApiUrl = "http://10.0.2.2:8000/users/logout";
    final SharedPreferences prefs =  await SharedPreferences.getInstance();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logging out...'), duration: Duration(seconds: 1)),
    );

    try {
      final response = await _dio.post(logoutApiUrl,
        options: Options(
          headers: {

            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );
      if (response.statusCode == 200) {
        print('Logout successful.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else if (response.statusCode == 401) {
        refreshToken();
        _logoutApiCall(context);
      } else {
        print('Logout failed with status code: ${response.statusCode}');
      }
    }catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during logout: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).current;


    const Color headerColor = Color(0xFFA58DCA);
    String interestsString = "Not specified";
    if (user!.interests != null && user.interests!.isNotEmpty) {
      interestsString = user.interests!.join(', ');
    }

    return Scaffold(
      body: Column(
        children: [
          // Custom header
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Row(
                  children: [
                    const SizedBox(width: 10), // Placeholder if cannot pop
                    const Expanded(
                      child: Text(
                        "My Profile", // Page Title
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // For symmetry
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile card
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: headerColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3))]
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white,
                            backgroundImage: (user.profile_image != null && user.profile_image!.isNotEmpty)
                                ? NetworkImage("http://10.0.2.2:8000/uploads/profile_pics/${user.profile_image!}")
                                : null,
                            child: (user.profile_image == null || user.profile_image!.isEmpty)
                                ? Icon(Icons.person, color: headerColor, size: 40)
                                : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  // Use name getter if available, otherwise construct from first/last
                                  user.name.isNotEmpty ? user.name : '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  // Use name getter if available, otherwise construct from first/last
                                  user.age != null ? 'Age: ${user.age}' : '',
                                  style: const TextStyle(color: Colors.white, fontSize: 15, ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),

                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Display User's Interests
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Interests: $interestsString",
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Buttons: Edit Profile and Logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute space
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _showEditProfileDialog(context);
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: headerColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 15)
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _logoutApiCall(context);
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text("Logout", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent, // Different color for logout
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 15)
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Display User Rating
                  Text(
                    "Your Rating",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (user.rating != null && user.rating! > 0)
                    RatingBarIndicator(
                      rating: user.rating!,
                      itemBuilder: (context, index) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      itemCount: 5,
                      itemSize: 35.0,
                      direction: Axis.horizontal,
                    )
                  else
                    Text(
                      "No ratings yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 5),
                  if (user.rating != null && user.rating! > 0)
                    Text(
                      "${user.rating!.toStringAsFixed(1)} / 5.0",
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'AI'), // Changed icon
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 159, 134, 192),
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 5,
      ),
    );
  }
}
