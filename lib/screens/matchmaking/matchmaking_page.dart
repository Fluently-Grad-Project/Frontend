import 'package:besso_fluently/screens/matchmaking/matchmade_profile_voicecall.dart';
import 'package:besso_fluently/screens/matchmaking/user_chat_request_page.dart';
import 'package:besso_fluently/screens/matchmaking/user_making_call_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'call_manager.dart';
import 'package:flutter/material.dart';
// Keep if you use rating bar in profile or elsewhere
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart'; // Ensure this path is correct and User model is updated
import 'VoiceCallScreen.dart';
import 'after_call_page.dart'; // Keep if used
import 'matchmade_profile_page.dart'; // Keep if used



import 'package:besso_fluently/screens/matchmaking/matchmade_profile_voicecall.dart';
import 'dart:async';
import 'package:besso_fluently/screens/matchmaking/InCallScreen.dart';
import 'package:besso_fluently/screens/matchmaking/user_chat_request_page.dart';
import 'package:besso_fluently/screens/matchmaking/user_making_call_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:permission_handler/permission_handler.dart';
class MatchmakingPage extends StatefulWidget {
  const MatchmakingPage({super.key});

  @override
  State<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends State<MatchmakingPage> {
  int _selectedIndex = 2; // Default for 'Chat/Matchmaking'

  final CallManager _callManager = CallManager();
  bool _isCallDialogShowing = false;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

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
      // Already on Matchmaking page
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/ai');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/account');
        break;
    }
  }

  final Dio _dio = Dio();
  List<User> _allFetchedUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;

  // --- Filter State Variables ---
  String? _selectedGender;
  RangeValues? _selectedAgeRange;

  final List<String> _availableInterests = [
    "Art", "Beauty", "Books", "Business and Entrepreneurship", "Cars and Automobiles",
    "Cooking", "DIY and Crafts", "Education", "Fashion", "Finance and Investment",
    "Fitness", "Food and Dining", "Gaming", "Gardening", "Health and Wellness",
    "History", "Movies", "Music" , "Nature", "Outdoor activities" ,
    "Parenting and Family", "Pets", "Photography", "Politics", "Science",
    "Sports", "Technology", "Travel"
  ];
  final Set<String> _selectedInterests = {};

  final double _minPossibleAge = 18;
  final double _maxPossibleAge = 70;

  // Profile Data
  int? _fetchedUserId;
  String? _firstName;
  String? _lastName;
  String? _gender;
  double? _rating;
  int? _age;
  String? _profileImageUrl;
  List<String>? _interests;
  String? _email;
  String? _error;

  // WebRTC and Firebase call related
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _iceSub;
  StreamSubscription<DocumentSnapshot>? _callStateSub;
  String? _currentlyHandledCallId;
  bool _isNavigatingToCallPage = false; // <- Add this to your class (not inside the function)
  final Set<String> _handledCallDocs = {};
  bool _listenerInitialized = false;

  late String _selfId;
  String _calleeId = '';
  String? _callDocId;

  String get _displayName {
    if (_firstName != null && _lastName != null && _firstName!.isNotEmpty && _lastName!.isNotEmpty) {
      return "$_firstName $_lastName";
    } else if (_firstName != null && _firstName!.isNotEmpty) {
      return _firstName!;
    } else if (_lastName != null && _lastName!.isNotEmpty) {
      return _lastName!;
    }
    return "User";
  }

  @override
  void initState() {
    super.initState();
    // _fetchUserData();
    _initRenderers();
    _selectedAgeRange = RangeValues(_minPossibleAge, _maxPossibleAge);
    _loadData();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    _iceSub?.cancel();
    _callStateSub?.cancel();
    super.dispose();
  }

  // Future<void> _fetchUserData() async {
  //   setState(() {
  //     _isLoading = true;
  //     _error = null;
  //   });
  //
  //   final String apiUrl = "http://192.168.1.14:8000/users/${user.id}/profile";
  //
  //   try {
  //     final response = await _dio.get(apiUrl);
  //     if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
  //       final data = response.data as Map<String, dynamic>;
  //       final birthDate = DateTime.tryParse(data['birth_date'] ?? '');
  //       int? calculatedAge;
  //       if (birthDate != null) {
  //         final today = DateTime.now();
  //         calculatedAge = today.year - birthDate.year;
  //         if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
  //           calculatedAge--;
  //         }
  //         if (calculatedAge < 0) calculatedAge = null;
  //       }
  //
  //       setState(() {
  //         _fetchedUserId = data['id'];
  //         _firstName = data['first_name'];
  //         _lastName = data['last_name'];
  //         _gender = data['gender'];
  //         _rating = (data['rating'] as num?)?.toDouble();
  //         _profileImageUrl = data['profile_image'];
  //         _interests = (data['interests'] as List?)?.cast<String>();
  //         _email = data['email'];
  //         _age = calculatedAge;
  //         _isLoading = false;
  //       });
  //     } else {
  //       throw Exception("Invalid response from server.");
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _error = "Failed to fetch profile: $e";
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<String?> getFirebaseUidByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
    } catch (e) {
      print("Error fetching Firebase UID: $e");
    }
    return null;
  }

  Future<void> _initRenderers() async {
    _selfId = _auth.currentUser!.uid;
    await _localRenderer.initialize();
    if (_remoteRenderer.textureId == null) {
      await _remoteRenderer.initialize();
    }
    await _initLocalStream();
    await _cleanPreviousCallsBetween(_selfId, _calleeId.trim());

    if (!_listenerInitialized) {
      setupCallListener();
      _listenerInitialized = true;
    }
  }

  Future<void> _initLocalStream() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) return;

    final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream = stream;
    _localRenderer.srcObject = _localStream;
    await Helper.setSpeakerphoneOn(true);
  }

  Future<void> _cleanPreviousCallsBetween(String userA, String userB) async {
    final calls = await _firestore.collection('calls').get();
    for (var doc in calls.docs) {
      final data = doc.data();
      final isBetween = (data['callerId'] == userA && data['calleeId'] == userB) ||
          (data['callerId'] == userB && data['calleeId'] == userA);
      if (isBetween) {
        await doc.reference.update({'callEnded': true});
        await doc.reference.collection('callerCandidates').get().then((snap) async {
          for (var cand in snap.docs) await cand.reference.delete();
        });
        await doc.reference.collection('calleeCandidates').get().then((snap) async {
          for (var cand in snap.docs) await cand.reference.delete();
        });
        await doc.reference.delete();
      }
    }
  }

  Future<void> setupCallListener() async {
    _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: _selfId)
        .where('type', isEqualTo: 'offer')
        .where('handledByCallee', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;

        print("📥 Incoming call: $docId");

        // 🛑 Skip if already navigating or already handled
        if (_isNavigatingToCallPage || _handledCallDocs.contains(docId) || _currentlyHandledCallId == docId) {
          print("🚫 Skipping call $docId (already navigating or handled)");
          continue;
        }

        _currentlyHandledCallId = docId; // ✅ Prevents handling the same call twice in parallel

        try {
          final docRef = _firestore.collection('calls').doc(docId);

          // ✅ Atomically mark as handled in Firestore
          final handled = await _firestore.runTransaction((txn) async {
            final snap = await txn.get(docRef);
            final callData = snap.data();
            if (callData == null || callData['handledByCallee'] == true) {
              print("⚠️ Call already handled in Firestore: $docId");
              return false;
            }
            txn.update(docRef, {'handledByCallee': true});
            return true;
          });

          if (!handled) {
            print("⛔️ Skipping navigation, call already handled by another device.");
            _currentlyHandledCallId = null;
            continue;
          }

          print("✅ Marked $docId as handled");

          _handledCallDocs.add(docId);
          _isNavigatingToCallPage = true;

          // ⏱ Safety fallback
          Future.delayed(const Duration(seconds: 15), () {
            if (_isNavigatingToCallPage && _currentlyHandledCallId == docId) {
              print("⏱ Fallback reset for $docId");
              _isNavigatingToCallPage = false;
              _currentlyHandledCallId = null;
            }
          });

          final callerId = data['callerId'];
          String callerName = "Unknown";

          try {
            final userDoc = await _firestore.collection('users').doc(callerId).get();
            if (userDoc.exists) {
              callerName = userDoc.data()?['username'] ?? "Unknown";
            }
          } catch (_) {}

          if (!mounted) return;

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserChatRequestPage(
                callerId: callerId,
                callerName: callerName,
                firebaseUid: _selfId,
                offerData: {...data, 'docId': docId},
              ),
            ),
          );

          print("🔙 Navigation result from UserChatRequestPage: $result");

          if (result == true) {
            print("📞 Answering call from $callerId");
            await _answerCall({...data, 'docId': docId});
          }
        } catch (e) {
          print("❌ Error handling incoming call: $e");
        } finally {
          if (mounted) {
            _isNavigatingToCallPage = false;
            _currentlyHandledCallId = null;
          }
        }
      }
    });
  }

  Future<void> _resetMediaState() async {
    if (_peerConnection != null) {
      _peerConnection!.onTrack = null;
      _peerConnection!.onIceCandidate = null;
      await _peerConnection!.close();
      await _peerConnection!.dispose();
      _peerConnection = null;
    }

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // ✅ Ensure both renderers are fully detached
    _localRenderer.srcObject = null;
    if (_remoteRenderer.srcObject != null) {
      for (var track in _remoteRenderer.srcObject!.getTracks()) {
        track.stop();
      }
    }
    _remoteRenderer.srcObject = null;

    await _iceSub?.cancel();
    _iceSub = null;
  }

  Future<void> _startCall() async {
    if (_calleeId.trim().isEmpty) {
      print("⚠️ Callee ID is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the Callee UID")),
      );
      return;
    }

    try {
      print("📞 Starting call to $_calleeId");

      await _cleanPreviousCallsBetween(_selfId, _calleeId.trim());
      print("🧹 Cleaned previous calls");

      // Optional: reset media state if you have such a method, otherwise initialize local stream
      if (mounted) {
        await _resetMediaState();  // if you have this method, else remove
        print("🔁 Reset media state");
      }

      await _remoteRenderer.initialize();
      await _initLocalStream();
      print("🎤 Local stream initialized");

      _peerConnection = await _createPeerConnection(isCaller: true);
      print("🔗 Peer connection created");

      // Add audio tracks to peer connection
      for (var track in _localStream!.getAudioTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print("📤 Offer created and set");

      final callDoc = await _firestore.collection('calls').add({
        'callerId': _selfId,
        'calleeId': _calleeId.trim(),
        'type': 'offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
        'handledByCallee':false,
        'timestamp': FieldValue.serverTimestamp(),
        'callEnded': false,  // <-- important!
      });

      _callDocId = callDoc.id;
      print("📁 Firestore call doc created: $_callDocId");

      _listenForRemoteIceCandidates(isCaller: true);

      // Here: Navigate immediately to UserMakingCallPage
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserMakingCallPage(
              callDocId: _callDocId!,
              selfId: _selfId,
              hangUp: _hangUp,
              onCallAnswered: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => InCallScreen(hangUp: _hangUp, selfId: _selfId),
                  ),
                );
              },
              userName: _displayName,
            ),
          ),
        );
      }

      await _callStateSub?.cancel(); // Cancel any previous listener
      _callStateSub = _firestore.collection('calls').doc(_callDocId!).snapshots().listen((docSnapshot) async {
        final data = docSnapshot.data();
        if (data == null) return;

        if (data['callEnded'] == true) {
          print("📴 Call ended");
          await _hangUp();
          // if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        if (data['type'] == 'answer') {
          print("✅ Answer received");
          final answer = RTCSessionDescription(data['sdp'], data['sdpType']);
          await _peerConnection?.setRemoteDescription(answer);
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => InCallScreen(hangUp: _hangUp, selfId: _selfId),
            ));
          }
        }
      });
    } catch (e, st) {
      print('❌ Error in _startCall: $e');
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start call: $e")),
      );
    }
  }

  Future<void> _answerCall(Map<String, dynamic> offerData) async {
    await _resetMediaState();

    _callDocId = offerData['docId'];
    await _initLocalStream();
    _peerConnection = await _createPeerConnection(isCaller: false);
    _localStream?.getAudioTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
    final offer = RTCSessionDescription(offerData['sdp'], offerData['sdpType']);
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _firestore.collection('calls').doc(_callDocId).update({
      'type': 'answer',
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });
    _listenForRemoteIceCandidates(isCaller: false);
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => InCallScreen(hangUp: _hangUp, selfId: _selfId)));
  }

  Future<RTCPeerConnection> _createPeerConnection({required bool isCaller}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final pc = await createPeerConnection(config);

    // ✅ Add local media tracks to the connection
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    } else {
      print('⚠️ Warning: _localStream is null when adding tracks');
    }

    // ✅ Handle remote tracks
    pc.onTrack = (event) {
      print('📥 Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        print('✅ Remote stream assigned to renderer');
      } else {
        print('⚠️ Remote stream is empty');
      }
    };

    // ✅ Handle ICE candidates
    pc.onIceCandidate = (candidate) async {
      if (_callDocId != null) {
        final ref = _firestore
            .collection('calls')
            .doc(_callDocId)
            .collection(isCaller ? 'callerCandidates' : 'calleeCandidates');
        await ref.add(candidate.toMap());
      }
    };

    return pc;
  }

  Future<void> _listenForRemoteIceCandidates({required bool isCaller}) async {
    final ref = _firestore
        .collection('calls')
        .doc(_callDocId)
        .collection(isCaller ? 'calleeCandidates' : 'callerCandidates');
    _iceSub = ref.snapshots().listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            final cand = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
            _peerConnection?.addCandidate(cand);
          }
        }
      }
    });
  }

  Future<void> _hangUp() async {
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      await _localStream?.dispose();
      _localStream = null;
    }

    if (_remoteRenderer.srcObject != null) {
      for (var track in _remoteRenderer.srcObject!.getTracks()) {
        track.stop();
      }
      _remoteRenderer.srcObject = null;
    }

    await _iceSub?.cancel();
    _iceSub = null;

    await _callStateSub?.cancel();
    _callStateSub = null;

    if (_callDocId != null) {
      final docRef = _firestore.collection('calls').doc(_callDocId);
      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data()?['callEnded'] != true) {
        await docRef.update({'callEnded': true});
      }

      for (final ref in [
        docRef.collection('callerCandidates'),
        docRef.collection('calleeCandidates')
      ]) {
        final snapshot = await ref.get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      _callDocId = null;
    }

    _calleeId = '';         // ✅ Add this line
    _callDocId = null;      // ✅ Reset call ID
    setState(() {});
  }

  // Future<String?> getFirebaseUidByEmail(String email) async {
  //   try {
  //     final snapshot = await FirebaseFirestore.instance
  //         .collection('users')
  //         .where('email', isEqualTo: email)
  //         .limit(1)
  //         .get();
  //
  //     if (snapshot.docs.isNotEmpty) {
  //       return snapshot.docs.first.id; // Firestore document ID is the Firebase UID
  //     }
  //   } catch (e) {
  //     print("Error fetching Firebase UID by email: $e");
  //   }
  //   return null;
  // }

  Future<void> _loadData() async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    // Prevent multiple simultaneous loads if _isLoading is already true,
    // unless _allFetchedUsers is empty (allowing initial load even if a previous one was interrupted).
    if (_isLoading && _allFetchedUsers.isNotEmpty) {
      print("MatchmakingPage: Load already in progress or initial data present. Skipping refresh.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // 1. Fetch initial list of matched user IDs and similarity scores
    String matchmakingUrl = "http://192.168.1.14:8000/matchmaking/get-matched-users?n_recommendations=5";
    List<User> fullyFetchedUsers = [];

    try {
      print("MatchmakingPage: Fetching matched user IDs from: $matchmakingUrl");
      Response matchmakingRes = await _dio.get(
        matchmakingUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );

      if (matchmakingRes.statusCode == 200 && matchmakingRes.data is List) {
        List<dynamic> matchedUsersData = matchmakingRes.data as List<dynamic>;
        print("MatchmakingPage: Received ${matchedUsersData.length} matched user entries.");

        List<Future<User?>> profileFetchFutures = [];

        for (var matchedEntry in matchedUsersData) {
          if (matchedEntry is Map<String, dynamic>) {
            final int? userId = matchedEntry['user_id'] as int?;
            final double? similarityScore = (matchedEntry['similarity_score'] as num?)?.toDouble();
            // You can also extract other data like 'interests' from this initial call if needed
            // final List<String>? initialInterests = (matchedEntry['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList();

            if (userId != null) {
              profileFetchFutures.add(
                  _fetchUserProfile(userId, prefs.getString("token"), initialData: matchedEntry) // Pass initial data
              );
            } else {
              print("MatchmakingPage: Found a matched entry with null user_id: $matchedEntry");
            }
          }
        }

        // 2. Fetch full profiles for all matched user IDs concurrently
        final List<User?> fetchedProfiles = await Future.wait(profileFetchFutures);

        fullyFetchedUsers = fetchedProfiles.where((user) => user != null).cast<User>().toList();


        print("MatchmakingPage: Successfully fetched and processed ${fullyFetchedUsers.length} full user profiles.");

      } else {
        print("MatchmakingPage: Failed to get valid data from matchmaking endpoint. Status: ${matchmakingRes.statusCode}, Data: ${matchmakingRes.data}");
        _allFetchedUsers = []; // Clear users on error from matchmaking endpoint
      }
    } catch (e, s) {
      print("MatchmakingPage: Error during initial matchmaking fetch or profile fetching: $e. Stacktrace: $s");
      _allFetchedUsers = []; // Clear users on any error during the process
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load matched users. ${e.toString()}'))
        );
      }
    } finally {
      _allFetchedUsers = fullyFetchedUsers; // Update the main list
      _applyFilters(); // Apply any active filters to the newly fetched data
      if (mounted) {
        setState(() {
          _isLoading = false;
          print("MatchmakingPage: _loadData finished. Set _isLoading = false. _filteredUsers count: ${_filteredUsers.length}");
        });
      } else {
        // If not mounted, just update the flag, data is already set.
        _isLoading = false;
        print("MatchmakingPage: _loadData finished (widget not mounted). Set _isLoading = false.");
      }
    }
  }

  // Helper method to fetch individual user profile
  // Takes initialData from the matchmaking endpoint to preserve similarity_score and other direct fields.
  Future<User?> _fetchUserProfile(int userId, String? token, {required Map<String, dynamic> initialData}) async {
    String profileUrl = "http://192.168.1.14:8000/users/$userId/profile";
    try {
      print("MatchmakingPage: Fetching profile for user ID $userId from $profileUrl");
      Response profileRes = await _dio.get(
        profileUrl,
      );

      if (profileRes.statusCode == 200 && profileRes.data is Map<String, dynamic>) {
        Map<String, dynamic> profileJson = profileRes.data as Map<String, dynamic>;

        // Combine initialData (especially for similarity_score) with profileJson.
        // ProfileJson data should take precedence for user details if there are overlaps,
        // but we ensure similarity_score from initialData is preserved.
        Map<String, dynamic> combinedJson = {...initialData, ...profileJson};

        // If your User.fromJson doesn't directly handle similarityScore,
        // you might pass it separately or ensure User model is updated.
        // Assuming User.fromJson can take a Map that includes 'similarity_score'
        // and other fields from *both* initial matchmaking response and profile response.
        // Your User.fromJson needs to be robust enough to pick the correct fields.
        // For example, use userId from initialData or profileJson (ensure consistency).
        // Ensure user_id is consistently used or map id from profile to user_id.

        // Correcting user_id: profile endpoint might return 'id', matchmaking 'user_id'
        if (profileJson.containsKey('id') && !profileJson.containsKey('user_id')) {
          combinedJson['user_id'] = profileJson['id'];
        }


        // Explicitly set similarityScore if it's not directly in combinedJson for User.fromJson
        double? similarityScore = (initialData['similarity_score'] as num?)?.toDouble();

        User user = User.fromJson(combinedJson); // User.fromJson should handle all fields including similarity_score

        // If User.fromJson doesn't handle similarityScore directly, use copyWith or set it after creation:



        return user;
      } else {
        print("MatchmakingPage: Failed to fetch profile for user ID $userId. Status: ${profileRes.statusCode}, Data: ${profileRes.data}");
        return null; // Return null if profile fetch fails
      }
    } catch (e, s) {
      print("MatchmakingPage: Error fetching profile for user ID $userId: $e. Stacktrace: $s");
      return null; // Return null on exception
    }
  }


  void _applyFilters() {
    if (!mounted) {
      print("MatchmakingPage: _applyFilters called but widget is not mounted. Aborting.");
      return;
    }

    print("\nMatchmakingPage: --- Applying Filters ---");
    print("MatchmakingPage: Current _allFetchedUsers count: ${_allFetchedUsers.length}");
    print("MatchmakingPage: Selected Gender (raw): '$_selectedGender'");
    print("MatchmakingPage: Selected Age Range: ${_selectedAgeRange?.start.round()}-${_selectedAgeRange?.end.round()} (Min: $_minPossibleAge, Max: $_maxPossibleAge)");
    print("MatchmakingPage: Selected Interests (raw): $_selectedInterests");

    // Determine if any actual filtering needs to be done
    final bool noGenderFilter = _selectedGender == null || _selectedGender!.trim().isEmpty;
    final bool noAgeFilter = _selectedAgeRange == null ||
        (_selectedAgeRange!.start == _minPossibleAge && _selectedAgeRange!.end == _maxPossibleAge);
    final bool noInterestsFilter = _selectedInterests.isEmpty;

    if (noGenderFilter && noAgeFilter && noInterestsFilter) {
      _filteredUsers = List.from(_allFetchedUsers);
      print("MatchmakingPage: No active filters. Displaying all ${_allFetchedUsers.length} users.");
    } else {
      // Pre-process selected gender and interests for efficient comparison within the loop
      final String? processedSelectedGender = _selectedGender?.trim().toLowerCase();
      final Set<String> processedSelectedInterests = _selectedInterests
          .map((interest) => interest.trim().toLowerCase())
          .where((interest) => interest.isNotEmpty) // Filter out empty strings after trimming
          .toSet();

      print("MatchmakingPage: Processed Selected Gender for matching: '$processedSelectedGender'");
      print("MatchmakingPage: Processed Selected Interests for matching: $processedSelectedInterests");

      _filteredUsers = _allFetchedUsers.where((user) {
        print("\nMatchmakingPage: Filtering User ID: ${user.id}, Name: ${user.name}");
        print("  Raw User Data: Gender='${user.gender}', Age='${user.age}', Interests='${user.interests}'");

        // 1. Gender Match
        bool genderMatch = true; // Assume match if no gender filter is active
        if (!noGenderFilter && processedSelectedGender != null) { // Check processedSelectedGender for null just in case
          final userGenderProcessed = user.gender?.trim().toLowerCase();
          genderMatch = userGenderProcessed == processedSelectedGender;
          print("  Gender Check: User='${userGenderProcessed ?? 'N/A'}', Selected='$processedSelectedGender', Match=$genderMatch");
        } else {
          print("  Gender Check: No active gender filter or selected gender is effectively null/empty.");
        }

        // 2. Age Match
        bool ageMatch = true; // Assume match if no age filter is active
        if (!noAgeFilter && _selectedAgeRange != null) { // _selectedAgeRange should not be null here due to noAgeFilter check
          if (user.age != null) {
            ageMatch = user.age! >= _selectedAgeRange!.start && user.age! <= _selectedAgeRange!.end;
            print("  Age Check: UserAge=${user.age}, Range=${_selectedAgeRange!.start.round()}-${_selectedAgeRange!.end.round()}, Match=$ageMatch");
          } else {
            ageMatch = false; // User has no age, so doesn't match a specific age range filter
            print("  Age Check: UserAge=null, Match=false (Age filter active)");
          }
        } else {
          print("  Age Check: No active age filter.");
        }

        // 3. Interests Match
        bool interestsMatch = true; // Assume match if no interest filter is active
        if (!noInterestsFilter && processedSelectedInterests.isNotEmpty) {
          final Set<String> userInterestsProcessed = user.interests
              ?.map((interest) => interest.trim().toLowerCase())
              .where((interest) => interest.isNotEmpty) // Filter out empty strings
              .toSet() ??
              {}; // Default to an empty set if user.interests is null

          print("  User Interests (processed): $userInterestsProcessed");

          if (userInterestsProcessed.isNotEmpty) {
            // Check if any of the user's processed interests are present in the selected processed interests.
            // OR, if ALL selected interests must be present (depends on desired logic)
            // Current logic: user must have AT LEAST ONE of the selected interests.
            interestsMatch = processedSelectedInterests.any((selectedInterest) {
              final matchFound = userInterestsProcessed.contains(selectedInterest);
              // This print can be very verbose, enable if deep debugging specific interest matches
              // print("    Comparing selected interest: '$selectedInterest' with user's set. Individual Match: $matchFound");
              return matchFound;
            });
            print("  Interests Check (any match): Overall Match for user's interests = $interestsMatch");
          } else {
            // User has no interests, but filter requires some.
            interestsMatch = false;
            print("  Interests Check: User has no processable interests; interestsMatch set to false (Interest filter active).");
          }
        } else {
          print("  Interests Check: No active interest filter.");
        }

        final bool finalMatch = genderMatch && ageMatch && interestsMatch;
        print("  Overall Match for User ID ${user.id}: $finalMatch (Gender: $genderMatch, Age: $ageMatch, Interests: $interestsMatch)");
        return finalMatch;
      }).toList();
    }

    print("MatchmakingPage: Filters applied. Final _filteredUsers count: ${_filteredUsers.length} out of ${_allFetchedUsers.length}.");
    // Important: This function should NOT call setState itself regarding _filteredUsers.
    // The calling context (e.g., after loading data or after filter dialog applies) is responsible
    // for calling setState to trigger a UI rebuild with the new _filteredUsers.
  }

  void _showFilterDialog() {
    String? dialogSelectedGender = _selectedGender;
    RangeValues dialogSelectedAgeRange = _selectedAgeRange ?? RangeValues(_minPossibleAge, _maxPossibleAge);
    Set<String> dialogSelectedInterests = Set.from(_selectedInterests);

    showDialog(
      context: context,
      barrierDismissible: false, // User must explicitly cancel or apply
      builder: (BuildContext context) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog's internal state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Filter Options"),
              contentPadding: const EdgeInsets.all(16.0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text("Gender:", style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: dialogSelectedGender,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      hint: const Text("Any Gender"),
                      isExpanded: true,
                      items: ["Male", "Female", "Any"] // "Any" will correspond to null
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value == "Any" ? null : value.toLowerCase(), // Store as lowercase, or null for "Any"
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          dialogSelectedGender = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text("Age Range:", style: TextStyle(fontWeight: FontWeight.bold)),
                    RangeSlider(
                      values: dialogSelectedAgeRange,
                      min: _minPossibleAge,
                      max: _maxPossibleAge,
                      divisions: (_maxPossibleAge - _minPossibleAge).toInt(), // One division per year
                      labels: RangeLabels(
                        dialogSelectedAgeRange.start.round().toString(),
                        dialogSelectedAgeRange.end.round().toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setDialogState(() {
                          dialogSelectedAgeRange = values;
                        });
                      },
                    ),
                    Text(
                      "Selected: ${dialogSelectedAgeRange.start.round()} - ${dialogSelectedAgeRange.end.round()} years",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    const Text("Interests:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0, // Horizontal space between chips
                      runSpacing: 0.0, // Vertical space between chip lines
                      children: _availableInterests.map((interest) {
                        return FilterChip(
                          label: Text(interest, style: const TextStyle(fontSize: 12)),
                          selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
                          selected: dialogSelectedInterests.contains(interest),
                          onSelected: (bool selected) {
                            setDialogState(() {
                              if (selected) {
                                dialogSelectedInterests.add(interest);
                              } else {
                                dialogSelectedInterests.remove(interest);
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
                TextButton(
                  child: const Text("Clear All"),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    setState(() { // Update main page state
                      _selectedGender = null;
                      _selectedAgeRange = RangeValues(_minPossibleAge, _maxPossibleAge);
                      _selectedInterests.clear();
                      _isLoading = true; // Show loading indicator while re-filtering
                    });
                    _applyFilters(); // Apply cleared filters
                    setState(() { _isLoading = false; }); // Hide loading indicator
                  },
                ),
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text("Apply Filters"),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    setState(() { // Update main page state with dialog's selections
                      _selectedGender = dialogSelectedGender;
                      _selectedAgeRange = dialogSelectedAgeRange;
                      _selectedInterests.clear();
                      _selectedInterests.addAll(dialogSelectedInterests);
                      _isLoading = true; // Show loading indicator
                    });
                    _applyFilters(); // Apply new filters
                    setState(() { _isLoading = false; }); // Hide loading indicator
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _usersListView() {
    print("MatchmakingPage: _usersListView called. Rendering ${_filteredUsers.length} filtered users (Total fetched: ${_allFetchedUsers.length}). Loading: $_isLoading");

    if (_isLoading && _filteredUsers.isEmpty && _allFetchedUsers.isEmpty) { // Only show global loading if truly no data yet
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredUsers.isEmpty && !_isLoading) {
      // Determine if it's because no users were fetched at all, or if filters cleared them
      String message = _allFetchedUsers.isEmpty
          ? "No users available at the moment. Pull to refresh or try again later."
          : "No users match your current filters. Try adjusting them or clearing filters!";
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Show loading indicator on top of list if refreshing filtered results
    if (_isLoading && _filteredUsers.isNotEmpty) {
      return Stack(
        children: [
          ListView.builder( // Display current list while loading new
            padding: const EdgeInsets.all(8.0),
            itemCount: _filteredUsers.length,
            itemBuilder: _buildUserCard,
          ),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData, // This will re-fetch and re-apply filters
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _filteredUsers.length,
        itemBuilder: _buildUserCard,
      ),
    );
  }


  Widget _buildUserCard(BuildContext context, int index) {
    User user = _filteredUsers[index];

    // Prepare display strings (similar to your existing logic, but we'll use them differently)
    String nameDisplay = user.name; // Assumes user.name is correctly populated (e.g., "John Doe")
    String? genderDisplay;
    if (user.gender != null && user.gender!.isNotEmpty) {
      genderDisplay = user.gender![0].toUpperCase() + user.gender!.substring(1); // e.g., "Male"
    }
    String? ageDisplay;
    if (user.age != null) {
      ageDisplay = "${user.age} years old"; // e.g., "30 years old"
    }

    // Rating - assuming user.rating is the field from your User model that holds the average rating
    double? ratingValue = user.rating; // Corrected to use averageRating as per previous discussions

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          print("MatchmakingPage: Card tapped for user: ${user.name}, ID: ${user.id}");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchMadeProfile(userId: user.id),
            ),
          );
        },

        borderRadius: BorderRadius.circular(12), // Match card's border radius for ink splash
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Increased padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Vertically center align items in the main Row
            children: [
              // Avatar
              CircleAvatar(
                radius: 35, // Slightly larger avatar
                backgroundColor: Colors.grey[200],
                backgroundImage: (user.profile_image != null && user.profile_image!.isNotEmpty)
                    ? NetworkImage(user.profile_image!)
                    : null,
                child: (user.profile_image == null || user.profile_image!.isEmpty)
                    ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 26, // Adjusted size
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColorDark, // Example color
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 16),

              // Middle Column: Name, Gender, Age
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Important to keep column height tight
                  children: [
                    // Name
                    Text(
                      nameDisplay,
                      style: const TextStyle(
                        fontSize: 18, // Slightly larger name
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Gender (under name)
                    if (genderDisplay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0), // Space between name and gender
                        child: Text(
                          genderDisplay,
                          style: TextStyle(
                            fontSize: 14, // Adjusted size
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Age (under gender)
                    if (ageDisplay != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3.0), // Space between gender and age
                        child: Text(
                          ageDisplay,
                          style: TextStyle(
                            fontSize: 14, // Adjusted size
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // Space before the right column (call icon & rating)

              // Right Column: Call Icon and Rating
              Column(
                mainAxisSize: MainAxisSize.min, // Keep column height tight
                crossAxisAlignment: CrossAxisAlignment.center, // Center items in this column
                children: [
                  // Call Icon (using your existing CircleAvatar approach)
                  CircleAvatar(
                    radius: 22, // Adjusted radius
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: IconButton(
                      icon: Icon(Icons.call),
                        onPressed: () async {
                          print("📞 Call icon pressed");

                          _email = user.email; // ✅ Assign email here before anything else

                          if (_email == null) {
                            print("❌ _email is null");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Email is not available.")),
                            );
                            return;
                          }

                          final firebaseUid = await getFirebaseUidByEmail(_email!);
                          print("📥 Firebase UID: $firebaseUid");

                          if (firebaseUid != null) {
                            _calleeId = firebaseUid;
                            await _startCall();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Failed to get user UID from Firebase.")),
                            );
                          }
                        }
                    ),
                  ),
                  const SizedBox(height: 6), // Space between call icon and rating

                  // Rating (under call icon)

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.stars,
                        color: Colors.amber, // Yellow star
                        size: 16,
                      ),
                    ],
                  )

                  // Placeholder to maintain some height consistency if no rating
                  // Adjust height as needed, or remove if you don't mind height changes

                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Your Match", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: "Filter Users",
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _usersListView(), // The main content is the list view
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), activeIcon: Icon(Icons.account_circle), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFA58DCA), // Theme color
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 5,
      ),
    );
  }
}