import 'package:besso_fluently/screens/matchmaking/VoiceCallScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
// Assuming your User model is in this path (though not directly used for instantiation here)
// import '../../models/user_model.dart';
import '../matchmaking/after_call_page.dart'; // Ensure this path is correct
import '../matchmaking/user_making_call_page.dart';

class MatchMadeProfile extends StatefulWidget {
  final int userId;

  const MatchMadeProfile({super.key, required this.userId});

  @override
  State<MatchMadeProfile> createState() => _MatchMadeProfileState();
}

class _MatchMadeProfileState extends State<MatchMadeProfile> {
  // Store individual fields extracted from the JSON
  int? _fetchedUserId; // To store the ID from the fetched JSON, if needed for cross-check
  String? _firstName;
  String? _lastName;
  String? _gender;
  double? _rating;
  int? _age;
  String? _profileImageUrl;
  List<String>? _interests;
  String? _email;

  bool _isLoading = true;
  String? _error;
  final Dio _dio = Dio();

  // Getter for full name for convenience in UI
  String get _displayName {
    if (_firstName != null && _lastName != null && _firstName!.isNotEmpty && _lastName!.isNotEmpty) {
      return "$_firstName $_lastName";
    } else if (_firstName != null && _firstName!.isNotEmpty) {
      return _firstName!;
    } else if (_lastName != null && _lastName!.isNotEmpty) {
      return _lastName!;
    }
    return "User"; // Fallback if no names are present or they are empty
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<String?> getFirebaseUidByEmail(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id; // Firestore document ID = Firebase UID
      }
    } catch (e) {
      print("Error fetching Firebase UID by email: $e");
    }
    return null;
  }


  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      // Reset previous data
      _fetchedUserId = null;
      _firstName = null;
      _lastName = null;
      _gender = null;
      _rating = null;
      _age = null;
      _profileImageUrl = null;
      _interests = null;
    });

    final String apiUrl = "http://192.168.1.53:8000/users/${widget.userId}/profile";
    print("Fetching user profile from: $apiUrl for userId: ${widget.userId}");

    try {
      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          Map<String, dynamic> jsonData = response.data as Map<String, dynamic>;

          // --- Extract required data directly ---
          String? fetchedEmail = jsonData['email'] as String?;
          int? fetchedIdFromJson = jsonData['id'] as int?;
          String? fetchedFirstName = jsonData['first_name'] as String?;
          String? fetchedLastName = jsonData['last_name'] as String?;
          String? fetchedGender = jsonData['gender'] as String?;
          double? fetchedRating = (jsonData['rating'] as num?)?.toDouble();
          String? birthDateString = jsonData['birth_date'] as String?;
          String? fetchedProfileImage = jsonData['profile_image'] as String?;
          List<String>? fetchedInterests = (jsonData['interests'] as List<dynamic>?)
              ?.map((interest) => interest as String)
              .where((interest) => interest.isNotEmpty) // Filter out empty interests
              .toList();

          int? calculatedAge;
          if (birthDateString != null) {
            try {
              final dob = DateTime.parse(birthDateString);
              final today = DateTime.now();
              calculatedAge = today.year - dob.year;
              if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
                calculatedAge--;
              }
              if (calculatedAge < 0) calculatedAge = null; // Age can't be negative
            } catch (e) {
              print("Error parsing birth_date ('$birthDateString') for age: $e");
              calculatedAge = null;
            }
          }

          setState(() {
            _fetchedUserId = fetchedIdFromJson;
            _firstName = fetchedFirstName;
            _lastName = fetchedLastName;
            _gender = fetchedGender;
            _rating = fetchedRating;
            _age = calculatedAge;
            _profileImageUrl = fetchedProfileImage;
            _interests = (fetchedInterests != null && fetchedInterests.isNotEmpty) ? fetchedInterests : null;
            _isLoading = false;
            _email = fetchedEmail;
          });

        } else {
          throw Exception("Received null or malformed data from server. Expected a Map.");
        }
      } else {
        throw Exception("Failed to load user data. Status: ${response.statusCode}, Body: ${response.data}");
      }
    } on DioException catch (e) {
      print("DioException fetching user data: ${e.message}, Response: ${e.response?.data}");
      setState(() {
        _isLoading = false;
        if (e.response?.data != null && e.response?.data['detail'] != null) {
          _error = "Error: ${e.response!.data['detail']}";
        } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          _error = "Network error. Please check your connection and ensure the server is running at 10.0.2.2:8000.";
        } else {
          _error = "Failed to fetch profile: ${e.message}";
        }
      });
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
        _error = "An unexpected error occurred: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);
    const Color headerColor = Color(0xFFA58DCA); // Fluently Purple

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: canPop ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: headerColor), onPressed: () => Navigator.pop(context)) : null,
          title: Text("Loading Profile...", style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: canPop ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: headerColor), onPressed: () => Navigator.pop(context)) : null,
          title: const Text("Error", style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchUserData,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(backgroundColor: headerColor),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Check if essential data like name is loaded after attempting fetch.
    // _displayName getter provides a fallback "User" if names are null/empty.
    // So, we rely on _isLoading and _error to gate the main UI.
    // If _isLoading is false and _error is null, we proceed.

    String interestsString = "Not specified";
    if (_interests != null && _interests!.isNotEmpty) {
      interestsString = _interests!.join(', ');
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
                    if (canPop)
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.arrow_back_ios_new, color: headerColor, size: 24),
                        ),
                      )
                    else
                      const SizedBox(width: 40), // Placeholder if cannot pop
                    Expanded(
                      child: Text(
                        "${_displayName}'s Profile", // Use the displayName getter
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 40), // For symmetry
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView( // Added for potentially long content
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
                              backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                  ? NetworkImage(_profileImageUrl!) // Consider CachedNetworkImage for better performance
                                  : null,
                              child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                                  ? Icon(Icons.person, color: headerColor, size: 40)
                                  : null,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Text(
                                    // Display age and gender if available
                                    "Age: ${_age ?? 'N/A'}${_gender != null && _gender!.isNotEmpty ? ', Gender: $_gender' : ''}",
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Display rating if available and greater than 0
                                  if (_rating != null && _rating! > 0) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(Icons.stars, color: Colors.white70, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _rating!.toStringAsFixed(1), // Display rating with one decimal place
                                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ]
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Interests
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Interests: $interestsString",
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            maxLines: 3, // Allow more lines for interests
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_email == null || _email!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("User email not available to start call.")),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );

                        final firebaseUid = await getFirebaseUidByEmail(_email!);

                        Navigator.pop(context);

                        // Print email and UID for debugging
                        print("Email: $_email");
                        print("Firebase UID: $firebaseUid");

                        if (firebaseUid != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VoiceCallScreen(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Failed to get user UID from Firebase.")),
                          );
                        }
                      },
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: Text(
                        "Call ${_firstName ?? _displayName.split(' ')[0]}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 159, 134, 192),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20), // Added padding at the bottom
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}