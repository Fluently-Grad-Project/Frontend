import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/refresh_token_service.dart';


// --- Report User Logic (Copied from your provided code) ---
enum ReportReason {
  offensiveLanguage,
  hateSpeechRacism,
  offensiveName,
  harassment,
}

String getReportReasonText(ReportReason reason) {
  switch (reason) {
    case ReportReason.offensiveLanguage:
      return 'Offensive Language';
    case ReportReason.hateSpeechRacism:
      return 'Hate Speech / Racism';
    case ReportReason.offensiveName:
      return 'Offensive Name';
    case ReportReason.harassment:
      return 'Harassment';
  // default: // Not strictly necessary if all enum values are covered
  //   return '';
  }
}
// --- End of Report User Logic ---


class AfterCallPage extends StatefulWidget {
  final int userId; // Expecting userId to fetch details

  const AfterCallPage({super.key, required this.userId});

  @override
  State<AfterCallPage> createState() => _AfterCallPageState();
}

class _AfterCallPageState extends State<AfterCallPage> {
  User? _user;
  bool _isLoadingProfile = true;
  String? _profileError;
  final Dio _dio = Dio();

  double _currentRatingValueForUI = 0;
  bool _isSubmittingRating = false;

  bool _isSendingFriendRequest = false;
  bool _friendRequestSent = false;
  String? _friendRequestError;


  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    // ... (Your existing _fetchUserProfile method remains the same) ...
    // This method should populate the _user object
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
      _user = null;
    });

    final String apiUrl = "http://10.0.2.2:8000/users/${widget.userId}/profile";
    print("AfterCallPage: Fetching user profile from: $apiUrl for userId: ${widget.userId}");

    try {
      final response = await _dio.get(apiUrl);

      if (response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          Map<String, dynamic> jsonData = response.data as Map<String, dynamic>;
          int? fetchedId = jsonData['id'] as int?;
          if (fetchedId == null || fetchedId != widget.userId) {
            throw Exception("Fetched user ID does not match requested ID or is missing.");
          }
          // ... (rest of your parsing logic to create the _user object)
          String? firstName = jsonData['first_name'] as String?;
          String? lastName = jsonData['last_name'] as String?;
          String? gender = jsonData['gender'] as String?;
          double? rating = (jsonData['rating'] as num?)?.toDouble();
          String? birthDateString = jsonData['birth_date'] as String?;
          String? profileImage = jsonData['profile_image'] as String?;
          List<String>? interests = (jsonData['interests'] as List<dynamic>?)
              ?.map((interest) => interest.toString())
              .where((interest) => interest.isNotEmpty)
              .toList();
          int? calculatedAge;
          DateTime? parsedBirthDate;
          if (birthDateString != null) {
            try {
              parsedBirthDate = DateTime.parse(birthDateString);
              final today = DateTime.now();
              calculatedAge = today.year - parsedBirthDate.year;
              if (today.month < parsedBirthDate.month ||
                  (today.month == parsedBirthDate.month && today.day < parsedBirthDate.day)) {
                calculatedAge--;
              }
              if (calculatedAge < 0) calculatedAge = null;
            } catch (e) {
              print("AfterCallPage: Error parsing birth_date for age: $e");
            }
          }

          if (!mounted) return;
          setState(() {
            _user = User(
              id: fetchedId,
              firstName: firstName,
              lastName: lastName,
              gender: gender,
              rating: rating,
              age: calculatedAge,
              profile_image: profileImage,
              interests: interests,
            );
            _isLoadingProfile = false;
          });
        } else {
          throw Exception("Received null or malformed profile data. Expected a Map.");
        }
      } else {
        throw Exception("Failed to load profile. Status: ${response.statusCode}, Body: ${response.data}");
      }
    } on DioException catch (e) {
      if (!mounted) return;
      print("AfterCallPage: DioException fetching profile: ${e.message}, Response: ${e.response?.data}");
      setState(() {
        _isLoadingProfile = false;
        if (e.response?.data != null && e.response?.data['detail'] != null) {
          _profileError = "Error: ${e.response!.data['detail']}";
        } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
          _profileError = "Network error. Please check your connection.";
        } else {
          _profileError = "Failed to fetch profile: ${e.message}";
        }
      });
    } catch (e) {
      if (!mounted) return;
      print("AfterCallPage: Error fetching profile: $e");
      setState(() {
        _isLoadingProfile = false;
        _profileError = "An unexpected error occurred: $e";
      });
    }
  }

  // --- Add Friend Function (Copied and adapted, ensure User model has `id` and `name`) ---
  Future<void> _sendFriendRequest(BuildContext context, String recipientUserId, String recipientName) async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _isSendingFriendRequest = true;
      _friendRequestError = null;
    });

    final dio = Dio();
    final String friendRequestApiUrl = "http://10.0.2.2:8000/friends/request/$recipientUserId"; // TODO: Replace with your real API endpoint

    try {
      final response = await dio.post(
          friendRequestApiUrl,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${prefs.getString("token")}',
            },
          )

      );

      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Friend request sent successfully to $recipientUserId.');
        setState(() {
          _friendRequestSent = true;
          _isSendingFriendRequest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to $recipientName!'), backgroundColor: const Color(0xFFA58DCA)),
        );
      } else if (response.statusCode == 401){
        refreshToken();
        _sendFriendRequest(context, recipientUserId, recipientName);

      }else {
        print('Error sending friend request: ${response.statusCode} - ${response.data}');
        setState(() {
          _friendRequestError = 'Error: ${response.statusCode}. Please try again.';
          _isSendingFriendRequest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendRequestError!), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('DioError/Exception sending friend request: ${e.toString()}');
      setState(() {
        _friendRequestError = 'An unexpected error occurred. Please try again.';
        _isSendingFriendRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendRequestError!), backgroundColor: Colors.red),
      );
    }
  }
  // --- End of Add Friend Function ---

  // --- Report User Dialog and API Call (Copied and adapted) ---
  Future<void> _showReportUserDialog(BuildContext context, User userToReport) async {

    ReportReason? selectedReason;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Report ${userToReport.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Why are you reporting this user?'),
                    const SizedBox(height: 10),
                    ...ReportReason.values.map((reason) {
                      return RadioListTile<ReportReason>(
                        title: Text(getReportReasonText(reason)),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (ReportReason? value) {
                          setDialogState(() {
                            selectedReason = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Report'),
                  onPressed: selectedReason == null
                      ? null // Disable button if no reason selected
                      : () async {
                    Navigator.of(dialogContext).pop(); // Close dialog
                    // Use userToReport.id (ensure it's a String if your API expects that)
                    await _reportUserApiCall( userToReport.id.toString(), selectedReason!, context, userToReport.name);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _reportUserApiCall( String userIdToReport, ReportReason reason, BuildContext scaffoldContext, String reportedUserName) async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    final dio = Dio();
    const String reportApiUrl = "http://10.0.2.2:8000/reports/";
    String priority ;
    if (reason == ReportReason.offensiveLanguage) {
      priority = "MEDIUM";
    } else if (reason == ReportReason.hateSpeechRacism) {
      priority = "CRITICAL";
    } else if (reason == ReportReason.offensiveName) {
      priority = "LOW";
    } else {
      priority = "HIGH";
    }

    print("_reportUserApiCall: Reporting user $userIdToReport for ${reason.name} Priority: $priority");
    try {
      final response = await dio.post(
          reportApiUrl,
          data: {
            "reported_user_id": userIdToReport,
            "priority": priority,
            "reason": reason.name
          },
          options:  Options(
            headers: {
              'Authorization': 'Bearer ${prefs.getString("token")}'
            },
          )
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201|| response.statusCode == 307) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Text('$reportedUserName reported for ${getReportReasonText(reason)}.'),
            backgroundColor: const Color(0xFFA58DCA),
          ),
        );
      }else if(response.statusCode == 401){
        refreshToken();
        _reportUserApiCall( userIdToReport, reason, scaffoldContext, reportedUserName);

      }
      else {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(content: Text('Error reporting: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error reporting user: $e');
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text("You've already reported this user"), backgroundColor: Colors.red),
      );
    }
  }



  // ... (rest of the _AfterCallPageState code remains the same)

  Future<void> _submitRating(double ratingToSubmit) async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    if (_user == null) {
      print("Cannot submit rating, user is null.");
      return;
    }
    if (!mounted) return;

    // _currentRatingValueForSubmission is already set by onRatingUpdate
    setState(() {
      _isSubmittingRating = true;
    });


    final String rateUserApiUrl = "http://10.0.2.2:8000/users/rate-user/${_user!.id}";

    print("Submitting rating $ratingToSubmit for user ${_user!.id} to $rateUserApiUrl");

    try {
      final response = await _dio.post(
        rateUserApiUrl,
        data: {"rating": ratingToSubmit},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Rating submitted successfully: ${response.data}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Rating $ratingToSubmit submitted for ${_user!.name}!"),
            backgroundColor: const Color(0xFFA58DCA),
          ),
        );
        setState(() {
          _user?.rating = ratingToSubmit; // Optimistic update or parse from response
          // _currentRatingValueForSubmission is already what was submitted.
          _isSubmittingRating = false;
        });
        // Optionally, refresh: await _fetchUserRating(_user!.id);
      } else if (response.statusCode == 401){
        refreshToken();
        _submitRating(ratingToSubmit);
      }
      else {
        print("Error submitting rating: ${response.statusCode} - ${response.data}");
        String errorMessage = "Failed to submit rating. Status: ${response.statusCode}.";
        if (response.data != null && response.data['detail'] != null) {
          errorMessage = "Error: ${response.data['detail']}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
        setState(() {
          _isSubmittingRating = false;
          // Optional: Revert _currentRatingValueForSubmission if UX requires it
          // For example, if you stored the original value before this attempt:
          // _currentRatingValueForSubmission = _previousRatingValueBeforeAttempt;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      print("DioException submitting rating: ${e.message}, Response: ${e.response?.data}");
      String errorMessage = "An error occurred while submitting rating.";
      if (e.response?.data != null && e.response?.data['detail'] != null) {
        errorMessage = "Error: ${e.response!.data['detail']}";
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      setState(() {
        _isSubmittingRating = false;
      });
    } catch (e) {
      if (!mounted) return;
      print("Unexpected error submitting rating: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred."), backgroundColor: Colors.red),
      );
      setState(() {
        _isSubmittingRating = false;
      });
    }
  }

// ... (rest of the _AfterCallPageState code remains the same)


  @override
  Widget build(BuildContext context) {
    double _currentRatingValueForSubmission = 0.0 ;
    final bool canPop = Navigator.canPop(context);
    const Color headerColor = Color(0xFFA58DCA);

    if (_isLoadingProfile) {
      // ... (Your loading UI)
      return Scaffold(
        appBar: AppBar(
          leading: canPop ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: headerColor), onPressed: () => Navigator.pop(context)) : null,
          title: const Text("Loading Profile...", style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white, elevation: 1, centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileError != null) {
      // ... (Your error UI)
      return Scaffold(
        appBar: AppBar(
          leading: canPop ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: headerColor), onPressed: () => Navigator.pop(context)) : null,
          title: const Text("Error", style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white, elevation: 1, centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_profileError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchUserProfile,
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

    if (_user == null) {
      // ... (Your fallback UI if _user is still null)
      return Scaffold(
        appBar: AppBar(
          leading: canPop ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: headerColor), onPressed: () => Navigator.pop(context)) : null,
          title: const Text("Error", style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white, elevation: 1, centerTitle: true,
        ),
        body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("User data could not be loaded. Please try again.", textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _fetchUserProfile, child: const Text("Retry Fetching"))
              ],
            )
        ),
      );
    }

    final User userToDisplay = _user!; // Now we are sure _user is not null
    String interestsString = "Not specified";
    if (userToDisplay.interests != null && userToDisplay.interests!.isNotEmpty) {
      interestsString = userToDisplay.interests!.join(', ');
    }

    return Scaffold(
      body: Column(
        children: [
          // --- Custom Header ---
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
                      const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        // Use userToDisplay.name (or appropriate getter from your User model)
                        "Rate ${userToDisplay.firstName ?? userToDisplay.name}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),
          // --- Main Content Area ---
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView( // Added SingleChildScrollView
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- User Profile Card ---
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
                              // Use userToDisplay.profileImage (or appropriate field from your User model)
                              backgroundImage: (userToDisplay.profile_image != null && userToDisplay.profile_image!.isNotEmpty)
                                  ? NetworkImage("http://10.0.2.2:8000/uploads/profile_pics/${userToDisplay.profile_image!}")
                                  : null,
                              child: (userToDisplay.profile_image == null || userToDisplay.profile_image!.isEmpty)
                                  ? Icon(Icons.person, color: headerColor, size: 40)
                                  : null,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userToDisplay.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Age: ${userToDisplay.age ?? 'N/A'}${userToDisplay.gender != null && userToDisplay.gender!.isNotEmpty ? ', Gender: ${userToDisplay.gender}' : ''}",
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (userToDisplay.rating != null && userToDisplay.rating! > 0) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.stars, color: Colors.white70, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          " ${userToDisplay.rating!.toStringAsFixed(1)}",
                                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
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

                    // --- Interests Section ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text( // Simpler layout for interests
                        "Interests: $interestsString",
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        maxLines: 3, // Allow more lines for interests
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 20),


                    // --- Report and Add Friend Buttons (Order from your previous image) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // --- Report User Button (Using the style you defined previously) ---
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.report, color: Colors.white),
                              label: const Text("Report", style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                // Call the new dialog function
                                _showReportUserDialog(context, userToDisplay);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                textStyle: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // --- Add Friend Button (Using the style you defined previously and new state logic) ---
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSendingFriendRequest || _friendRequestSent
                                  ? null // Disable if sending or already sent
                                  : () {
                                _sendFriendRequest(context, userToDisplay.id.toString(), userToDisplay.name);
                              },
                              icon: _isSendingFriendRequest
                                  ? Container(
                                width: 18, // Adjusted for button padding
                                height: 18,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : Icon(
                                _friendRequestSent ? Icons.check : Icons.person_add_alt_1_outlined,
                                color: Colors.white,
                              ),
                              label: Text(
                                  _friendRequestSent ? "Request Sent" : (_isSendingFriendRequest ? "Sending..." : "Add Friend"),
                                  style: const TextStyle(color: Colors.white)
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _friendRequestSent ? Colors.grey[600] : headerColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                textStyle: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_friendRequestError != null) // Display friend request error
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_friendRequestError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),

                    const SizedBox(height: 20), // Spacing before rating

                    // --- Rating Section Title ---
                    Text(
                      "Rate ${userToDisplay.firstName ?? userToDisplay.name}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 15),

                    // --- Rating Bar ---
                    Column(
                      children: [
                        RatingBar.builder(
                          initialRating: _currentRatingValueForSubmission, // Reflects the last tap or fetched value
                          minRating: 1,
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,
                          itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                          itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                          onRatingUpdate: (rating) {
                            if (_isSubmittingRating) return; // Prevent updates if already submitting

                            // 1. Update the UI immediately to reflect the user's tap
                            setState(() {
                              _currentRatingValueForSubmission = rating;
                            });
                            // 2. Then, submit this rating to the backend
                            _submitRating(rating);
                          },
                          // If _isSubmittingRating is true, this will make it non-interactive
                          // It won't visually dim it here unless you add more logic to itemBuilder
                          ignoreGestures: _isSubmittingRating,
                        ),
                        if (_isSubmittingRating) ...[ // Show spinner only when submitting
                          const SizedBox(height: 10),
                          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(headerColor)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 30), // Extra padding at the bottom
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