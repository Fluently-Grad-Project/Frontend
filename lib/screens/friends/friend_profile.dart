import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../providers/Ip_provider.dart';
import '../../services/refresh_token_service.dart';

// Placeholder for ReportReason enum - ensure it matches yours
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


class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User user;
  final Dio _dio = Dio(); // For API calls

  double? _fetchedUserRating; // For displaying the most current rating
  bool _isLoadingRating = true; // To show loading state for rating initially
  bool _isSubmittingRating = false;
  // double _currentRatingValueForSubmission = 0.0; // Handled by RatingBar's onRatingUpdate directly

  // Placeholder for JWT token - replace with your actual token retrieval logic



  @override
  void initState() {
    super.initState();
    user = widget.user;
    _fetchInitialUserRating();
  }

  Future<void> _fetchInitialUserRating() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRating = true;
    });


    // For example:
    try {
      final response = await _dio.get("http://${IpAddress}:8000/users/${user.id}/rating" // Fictional endpoint
      );
      if (response.statusCode == 200 && response.data != null && response.data['average_rating'] != null) {
        _fetchedUserRating = (response.data['average_rating'] as num).toDouble();
      } else {
        _fetchedUserRating = user.rating; // Fallback to initial if any
      }
    } catch (e) {
      print("Error fetching initial rating: $e");
      _fetchedUserRating = user.rating; // Fallback
    }


    // Simulating a fetch or using the initial rating passed

    _fetchedUserRating = user.rating; // Initialize with the rating passed to the widget or fetched

    if (!mounted) return;
    setState(() {
      _isLoadingRating = false;
    });
  }

  Future<void> _blockUserApiCall(String userIdToBlock, String userName) async {
    // Use 10.0.2.2 for Android Emulator to connect to localhost on your machine

    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    final String blockUserApiUrl = "http://${IpAddress}:8000/users/block-user/$userIdToBlock";
    print("Attempting to block user $userIdToBlock at $blockUserApiUrl");

    if (!mounted) return;
    // Potentially show a loading indicator here if you want
    // setState(() { _isBlockingUser = true; });

    try {
      final response = await _dio.post(
        blockUserApiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        print("User $userName ($userIdToBlock) blocked successfully.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName has been blocked.'),
            backgroundColor: const Color(0xFFA58DCA), // Or Colors.green
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } else if (response.statusCode == 401) {
        refreshToken();
        _blockUserApiCall( userIdToBlock,  userName);
      } else {
        print("Error blocking user: ${response.statusCode} - ${response.data}");
        String errorMessage = "Failed to block $userName. Status: ${response.statusCode}.";
        if (response.data != null && response.data['detail'] != null) {
          errorMessage = "Error: ${response.data['detail']}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      print("DioException blocking user: ${e.message}, Response: ${e.response?.data}");
      String errorMessage = "An error occurred while blocking $userName.";
      if (e.response?.data != null && e.response?.data['detail'] != null) {
        errorMessage = "Error: ${e.response!.data['detail']}";
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      print("Unexpected error blocking user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred while blocking $userName."), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      // setState(() { _isBlockingUser = false; });
    }
  }
  // Block User Dialog
  Future<void> _showBlockConfirmDialog(BuildContext context, String userName, String userIdToBlock) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Block $userName?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to block $userName?'),
                const Text('You will not be able to see their messages or interact with them.'),
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
              child: const Text('Block', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the confirmation dialog first
                _blockUserApiCall(userIdToBlock, userName); // Call the API method
              },
            ),
          ],
        );
      },
    );
  }

  // Report User Dialog
  void _showReportUserDialog(BuildContext scaffoldContext, User userToReport) {
    ReportReason? selectedReason = ReportReason.harassment; // Default selection

    showDialog(
      context: scaffoldContext, // Use the context from the Scaffold
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Report ${userToReport.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ReportReason.values.map((ReportReason reason) {
                    return RadioListTile<ReportReason>(
                      title: Text(getReportReasonText(reason)),
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (ReportReason? value) {
                        setDialogState(() { // Use setDialogState from StatefulBuilder
                          selectedReason = value;
                        });
                      },
                    );
                  }).toList(),
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
                  child: const Text('Report', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    if (selectedReason == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar( // Show snackbar in dialog if needed
                        const SnackBar(content: Text('Please select a reason.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(); // Close the dialog first
                    _reportUserApiCall(userToReport.id.toString(), selectedReason!, scaffoldContext, userToReport.name);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // report user API call
  Future<void> _reportUserApiCall( String userIdToReport, ReportReason reason, BuildContext scaffoldContext, String reportedUserName) async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    final String reportApiUrl = "http://${IpAddress}:8000/reports/";
    String priority ;
    if (reason == ReportReason.offensiveLanguage) {
      priority = "MEDIUM";
    } else if (reason == ReportReason.hateSpeechRacism) {
      priority = "CRITICAL";
    } else if (reason == ReportReason.offensiveName) {
      priority = "LOW";
    } else { // spam, impersonation, other
      priority = "HIGH";
    }

    print("_reportUserApiCall: Reporting user $userIdToReport for ${reason.name} Priority: $priority");
    try {
      final response = await _dio.post(
          reportApiUrl,
          data: {
            "reported_user_id": userIdToReport,
            "priority": priority,
            "reason": reason.name // Or getReportReasonText(reason) depending on API
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
      } else if (response.statusCode == 401) {
        refreshToken();
        _reportUserApiCall(userIdToReport, reason, scaffoldContext, reportedUserName);
      } else {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(content: Text('Error reporting: ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error reporting user: $e');
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text("You've already submitted a report on this user"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submitRating(double ratingToSubmit) async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isSubmittingRating = true;
    });

    final String rateUserApiUrl = "http://${IpAddress}:8000/users/rate-user/${user.id}";
    print("Submitting rating $ratingToSubmit for user ${user.id} to $rateUserApiUrl");

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
            content: Text("Rating $ratingToSubmit submitted for ${user.name}!"),
            backgroundColor: const Color(0xFFA58DCA),
          ),
        );
        setState(() {
          // Assuming the API might return the new average rating.
          // If not, optimistically use ratingToSubmit.
          // Example: _fetchedUserRating = response.data['new_average_rating']?.toDouble() ?? ratingToSubmit;
          _fetchedUserRating = ratingToSubmit;
          _isLoadingRating = false; // Rating is now set
        });
      } else if (response.statusCode == 401) {
        refreshToken();
        _submitRating(ratingToSubmit);
      } else {
        print("Error submitting rating: ${response.statusCode} - ${response.data}");
        String errorMessage = "Failed to submit rating. Status: ${response.statusCode}.";
        if (response.data != null && response.data['detail'] != null) {
          errorMessage = "Error: ${response.data['detail']}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
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
    } catch (e) {
      if (!mounted) return;
      print("Unexpected error submitting rating: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred."), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmittingRating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);
    const Color headerColor = Color(0xFFA58DCA);

    return Scaffold(
      body: Column(
        children: [
          // custom header
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
                        "${user.name}'s Profile",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 40), // For balance with the back button
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // profile card
                    Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: headerColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 2, blurRadius: 5, offset: Offset(0, 3))]
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.white,
                              backgroundImage: (user.profile_image != null && user.profile_image!.isNotEmpty)
                                  ? NetworkImage("http://192.168.1.14:8000/uploads/profile_pics/${user.profile_image!}")
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
                                  Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Text(
                                      user.age != null ? "Age: ${user.age}" : "Age: N/A",
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                      overflow: TextOverflow.ellipsis
                                  ),
                                  // --- Corrected Rating Display ---
                                  if (_isLoadingRating && _fetchedUserRating == null) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "Loading rating...",
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  ] else if (_fetchedUserRating != null && _fetchedUserRating! > 0) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.stars, color: Colors.white.withOpacity(0.8), size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _fetchedUserRating!.toStringAsFixed(1), // Use the fetched/updated rating
                                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    )
                                  ] else ...[ // If not loading and no rating or rating is 0
                                    Row(
                                      children: [
                                        Icon(Icons.star_border, color: Colors.white.withOpacity(0.7), size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          "No rating yet",
                                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontStyle: FontStyle.italic),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    )
                                  ],
                                  // --- End of Corrected Rating Display ---
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- User Interests Section ---
                    if (user.interests != null && user.interests!.isNotEmpty) ...[
                      Text(
                        "Interests",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        alignment: WrapAlignment.center,
                        children: user.interests!.map((interest) => Chip(
                          label: Text(interest),
                          backgroundColor: headerColor.withOpacity(0.15),
                          labelStyle: TextStyle(color: headerColor.withOpacity(0.9), fontWeight: FontWeight.w500),
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        )).toList(),
                      ),
                      const SizedBox(height: 25),
                    ] else ...[
                      // Optional: Text("No interests to display.", style: TextStyle(color: Colors.grey)),
                      // const SizedBox(height: 25),
                    ],
                    // --- End of User Interests Section ---

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            _showBlockConfirmDialog(context, user.name, user.id.toString());
                          },
                          icon: Icon(Icons.block, color: Colors.black.withOpacity(0.7)),
                          label: Text("Block", style: TextStyle(color: Colors.black.withOpacity(0.7))),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.report, color: Colors.black),
                          label: Text("Report", style: TextStyle(color: Colors.black.withOpacity(0.7))),
                          onPressed: () {
                            _showReportUserDialog(context, user);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Rate Section
                    Text(
                      "Rate ${user.name}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (_isSubmittingRating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: CircularProgressIndicator(),
                      )
                    else
                      RatingBar.builder(
                        initialRating: _fetchedUserRating ?? 0.0, // Initialize with fetched or 0
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onRatingUpdate: (rating) {
                          _submitRating(rating);
                        },
                      ),
                    const SizedBox(height: 20), // Bottom padding
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