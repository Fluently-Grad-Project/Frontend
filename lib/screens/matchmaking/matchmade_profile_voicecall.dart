// import 'dart:async';
// import 'package:besso_fluently/screens/matchmaking/user_chat_request_page.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'InCallScreen.dart';
//
// class VoiceCallScreenprofile extends StatefulWidget {
//   final int userId;
//
//   const VoiceCallScreenprofile({super.key, required this.userId});
//
//   @override
//   State<VoiceCallScreenprofile> createState() => _VoiceCallScreenprofileState();
// }
//
// class _VoiceCallScreenprofileState extends State<VoiceCallScreenprofile> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final _localRenderer = RTCVideoRenderer();
//   final _remoteRenderer = RTCVideoRenderer();
//   RTCPeerConnection? _peerConnection;
//   MediaStream? _localStream;
//   StreamSubscription? _iceSub;
//   StreamSubscription<DocumentSnapshot>? _callStateSub;
//
//   late String _selfId;
//   String _calleeId = '';
//   String? _callDocId;
//   final TextEditingController _calleeController = TextEditingController();
//
//   int? _fetchedUserId;
//   String? _firstName;
//   String? _lastName;
//   String? _gender;
//   double? _rating;
//   int? _age;
//   String? _profileImageUrl;
//   List<String>? _interests;
//   String? _email;
//
//   bool _isLoadingProfile = true;
//   String? _error;
//   final Dio _dio = Dio();
//
//   String get _displayName {
//     if (_firstName != null && _lastName != null) {
//       return '$_firstName $_lastName';
//     } else if (_firstName != null) {
//       return _firstName!;
//     } else if (_lastName != null) {
//       return _lastName!;
//     }
//     return 'User';
//   }
//
//
//   @override
//   void initState() {
//     super.initState();
//     initRenderers();
//     setupCallListener();
//     _fetchUserData();
//   }
//
//   Future<void> _fetchUserData() async {
//     setState(() {
//       _isLoadingProfile = true;
//       _error = null;
//     });
//
//     try {
//       final user = _auth.currentUser;
//       if (user == null) return;
//
//       final userDoc = await _firestore.collection('users').doc(user.uid).get();
//       final email = userDoc['email'];
//       final response = await _dio.get("http://192.168.1.53:8000/users/${userDoc.id}/profile");
//
//       if (response.statusCode == 200) {
//         final data = response.data;
//         setState(() {
//           _firstName = data['first_name'];
//           _lastName = data['last_name'];
//           _gender = data['gender'];
//           _rating = (data['rating'] as num?)?.toDouble();
//           _profileImageUrl = data['profile_image'];
//           _email = email;
//
//           // Calculate age
//           final birthDate = DateTime.tryParse(data['birth_date']);
//           if (birthDate != null) {
//             final now = DateTime.now();
//             _age = now.year - birthDate.year - ((now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) ? 1 : 0);
//           }
//
//           final interestsRaw = data['interests'] as List?;
//           _interests = interestsRaw?.whereType<String>().toList();
//           _isLoadingProfile = false;
//         });
//       }
//     } catch (e) {
//       print('❌ Failed to fetch user profile: $e');
//       setState(() {
//         _error = 'Error fetching profile';
//         _isLoadingProfile = false;
//       });
//     }
//   }
//
//
//   Future<void> initRenderers() async {
//     _selfId = _auth.currentUser!.uid;
//     await _localRenderer.initialize();
//     await _remoteRenderer.initialize();
//     await _initLocalStream();
//     // 👇 Clean up any old call sessions for this user
//     await _cleanPreviousCallsBetween(_selfId, _selfId);
//   }
//
//   Future<void> _initLocalStream() async {
//     if (_localStream != null) {
//       for (var track in _localStream!.getTracks()) {
//         track.stop();
//       }
//       await _localStream?.dispose();
//     }
//
//     final micStatus = await Permission.microphone.request();
//     if (micStatus != PermissionStatus.granted) {
//       print('❌ Microphone permission not granted');
//       return;
//     }
//
//     final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
//     _localStream = stream;
//     _localRenderer.srcObject = _localStream;
//     await Helper.setSpeakerphoneOn(true);
//
//     for (var track in _localStream!.getAudioTracks()) {
//       track.enabled = true;
//     }
//     print('🎤 Local stream initialized with ${_localStream!.getAudioTracks().length} audio tracks');
//
//   }
//   Future<void> _cleanPreviousCallsBetween(String userA, String userB) async {
//     final callQuery = await _firestore.collection('calls').get();
//
//     for (var doc in callQuery.docs) {
//       final data = doc.data();
//       final caller = data['callerId'];
//       final callee = data['calleeId'];
//
//       // Match calls between userA and userB (in any direction)
//       final isBetween = (caller == userA && callee == userB) ||
//           (caller == userB && callee == userA);
//
//       if (isBetween) {
//         await doc.reference.update({'callEnded': true});
//
//         final subCollections = ['callerCandidates', 'calleeCandidates'];
//         for (var sub in subCollections) {
//           final snap = await doc.reference.collection(sub).get();
//           for (var candidate in snap.docs) {
//             await candidate.reference.delete();
//           }
//         }
//
//         await doc.reference.delete();
//       }
//     }
//   }
//
//   Future<void> _resetMediaState() async {
//     if (_peerConnection != null) {
//       _peerConnection!.onTrack = null;
//       _peerConnection!.onIceCandidate = null;
//       await _peerConnection!.close();
//       await _peerConnection!.dispose();
//       _peerConnection = null;
//     }
//
//     if (_localStream != null) {
//       for (var track in _localStream!.getTracks()) {
//         track.stop();
//       }
//       await _localStream!.dispose();
//       _localStream = null;
//     }
//
//     // ✅ Ensure both renderers are fully detached
//     _localRenderer.srcObject = null;
//     if (_remoteRenderer.srcObject != null) {
//       for (var track in _remoteRenderer.srcObject!.getTracks()) {
//         track.stop();
//       }
//     }
//     _remoteRenderer.srcObject = null;
//
//     await _iceSub?.cancel();
//     _iceSub = null;
//   }
//
//   Future<void> setupCallListener() async {
//     _firestore
//         .collection('calls')
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .listen((snapshot) async {
//       for (var doc in snapshot.docs) {
//         final data = doc.data();
//         if (data['calleeId'] == _selfId && data['type'] == 'offer') {
//           final dataWithId = Map<String, dynamic>.from(data);
//           dataWithId['docId'] = doc.id;
//           _callDocId = doc.id;
//
//           final String callerId = dataWithId['callerId'];
//
//           // 🔽 Fetch the caller's "username" from Firestore
//           String callerName = "Unknown";
//           try {
//             final userDoc = await _firestore.collection('users').doc(callerId).get();
//             if (userDoc.exists) {
//               callerName = userDoc.data()?['username'] ?? "Unknown";
//             }
//           } catch (e) {
//             print("❌ Error fetching caller name: $e");
//           }
//           // ✅ Navigate to your custom ringing screen
//           if (mounted) {
//             final result = await Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => UserChatRequestPage(
//                   callerId: callerId,
//                   callerName: callerName,
//                   firebaseUid: _selfId,
//                   offerData: dataWithId,
//                 ),
//               ),
//             );
//             // 👇 Accept button returns `true`, so we handle the answer here
//             if (result == true) {
//               await _answerCall(dataWithId);
//             }
//           }
//           break; // Only handle the first valid offer
//         }
//       }
//     });
//   }
//
//   void _showIncomingCallDialog(Map<String, dynamic> data) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Incoming Call"),
//         content: const Text("Someone is calling you."),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               _answerCall(data);
//             },
//             child: const Text("Accept"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _startCall() async {
//     if (_calleeId.trim().isEmpty) {
//       print("⚠️ Callee ID is empty");
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please enter the Callee UID")),
//       );
//       return;
//     }
//
//     try {
//       print("📞 Starting call to $_calleeId");
//
//       await _cleanPreviousCallsBetween(_selfId, _calleeId.trim());
//       print("🧹 Cleaned previous calls");
//
//       await _resetMediaState();
//       print("🔁 Reset media state");
//
//       await _remoteRenderer.initialize();
//       await _initLocalStream();
//       print("🎤 Local stream initialized");
//
//       _peerConnection = await _createPeerConnection(isCaller: true);
//       print("🔗 Peer connection created");
//
//       for (var track in _localStream!.getAudioTracks()) {
//         _peerConnection!.addTrack(track, _localStream!);
//       }
//
//       final offer = await _peerConnection!.createOffer();
//       await _peerConnection!.setLocalDescription(offer);
//       print("📤 Offer created and set");
//
//       final callDoc = await _firestore.collection('calls').add({
//         'callerId': _selfId,
//         'calleeId': _calleeId.trim(),
//         'type': 'offer',
//         'sdp': offer.sdp,
//         'sdpType': offer.type,
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//
//       _callDocId = callDoc.id;
//       print("📁 Firestore call doc created: $_callDocId");
//
//       _listenForRemoteIceCandidates(isCaller: true);
//
//       await _callStateSub?.cancel(); // ✅ Cancel old listener
//       _callStateSub = _firestore.collection('calls').doc(_callDocId!).snapshots().listen((docSnapshot) async {
//         final data = docSnapshot.data();
//         if (data == null) return;
//
//         if (data['callEnded'] == true) {
//           print("📴 Call ended");
//           await _hangUp();
//           if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
//           return;
//         }
//
//         if (data['type'] == 'answer') {
//           print("✅ Answer received");
//           final answer = RTCSessionDescription(data['sdp'], data['sdpType']);
//           await _peerConnection?.setRemoteDescription(answer);
//           if (mounted) {
//             Navigator.of(context).push(MaterialPageRoute(
//               builder: (_) => InCallScreen(hangUp: _hangUp, selfId: _selfId),
//             ));
//           }
//         }
//       });
//     } catch (e, st) {
//       print('❌ Error in _startCall: $e');
//       print(st);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to start call: $e")),
//       );
//     }
//   }
//
//   Future<void> _answerCall(Map<String, dynamic> offerData) async {
//     _callDocId = offerData['docId']; // ✅ Always overwrite with the correct document ID
//
//     if (_selfId == offerData['callerId']) {
//       print("⚠️ Caller and callee have the same UID. Ignoring call.");
//       return;
//     }
//
//     await _resetMediaState(); // ✅ Reset before anything else
//     await _remoteRenderer.initialize(); // ✅ Re-init renderer
//     await _initLocalStream(); // ✅ Ensure fresh local stream
//     _peerConnection = await _createPeerConnection(isCaller: false);
//
//     // 👇 1. Add local track BEFORE setting remote description
//     if (_localStream != null) {
//       for (var track in _localStream!.getAudioTracks()) {
//         print('🎤 [Answer] Adding local track: ${track.id}');
//         _peerConnection!.addTrack(track, _localStream!);
//       }
//     }
//
//     final offer = RTCSessionDescription(offerData['sdp'], offerData['sdpType']);
//     await _peerConnection!.setRemoteDescription(offer); // 👈 2. Now set remote description
//
//     final answer = await _peerConnection!.createAnswer();
//     await _peerConnection!.setLocalDescription(answer);
//
//     await _firestore.collection('calls').doc(_callDocId).update({
//       'type': 'answer',
//       'sdp': answer.sdp,
//       'sdpType': answer.type,
//     });
//
//     _listenForRemoteIceCandidates(isCaller: false);
//
//     if (mounted) {
//       Navigator.of(context).push(MaterialPageRoute(
//         builder: (_) => InCallScreen(
//           hangUp: _hangUp,
//           selfId: _selfId,
//         ),
//       ));
//     }
//
//     await _callStateSub?.cancel(); // Dispose previous listener
//     _callStateSub = _firestore.collection('calls').doc(_callDocId!).snapshots().listen((docSnapshot) async {
//       final data = docSnapshot.data();
//       if (data == null) return;
//
//       if (data['callEnded'] == true) {
//         print("📴 Call ended remotely");
//         await _hangUp();
//         if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
//         return;
//       }
//     });
//   }
//
//   Future<RTCPeerConnection> _createPeerConnection({required bool isCaller}) async {
//     final config = {
//       'iceServers': [
//         {'urls': 'stun:stun.l.google.com:19302'},
//       ]
//     };
//
//     final pc = await createPeerConnection(config);
//
//     pc.onTrack = (event) async {
//       print("📡 onTrack fired: received remote track");
//
//       if (event.streams.isNotEmpty) {
//         final remoteStream = event.streams.first;
//         print("🎧 Remote stream has ${remoteStream.getAudioTracks().length} audio tracks");
//
//         _remoteRenderer.srcObject = null; // Reset first
//         _remoteRenderer.srcObject = remoteStream;
//
//         await Helper.setSpeakerphoneOn(true); // Ensure output is speaker
//
//         // 🔊 Force enable audio tracks
//         for (var track in remoteStream.getAudioTracks()) {
//           print('🔊 Enabling remote audio track: ${track.id}');
//           track.enabled = true;
//           track.onEnded = () {
//             print('🚫 Remote audio track ended: ${track.id}');
//           };
//         }
//       } else {
//         print("⚠️ No remote stream in track event");
//       }
//     };
//
//     pc.onIceCandidate = (RTCIceCandidate candidate) async {
//       if (_callDocId != null) {
//         final candidatesCollection = _firestore
//             .collection('calls')
//             .doc(_callDocId)
//             .collection(isCaller ? 'callerCandidates' : 'calleeCandidates');
//
//         print("📤 Sending ICE candidate to ${isCaller ? 'callerCandidates' : 'calleeCandidates'}");
//         await candidatesCollection.add(candidate.toMap());
//       }
//     };
//     return pc;
//   }
//
//   Future<void> _listenForRemoteIceCandidates({required bool isCaller}) async {
//     final candidatesCollection = _firestore
//         .collection('calls')
//         .doc(_callDocId)
//         .collection(isCaller ? 'calleeCandidates' : 'callerCandidates');
//
//     print("📥 Listening for remote ICE candidates from ${isCaller ? 'calleeCandidates' : 'callerCandidates'}");
//
//     await _iceSub?.cancel(); // ✅ Proper cleanup before setting new one
//     _iceSub = candidatesCollection.snapshots().listen((snapshot) {
//       for (var doc in snapshot.docChanges) {
//         if (doc.type == DocumentChangeType.added) {
//           final data = doc.doc.data();
//           if (data != null) {
//             final candidate = RTCIceCandidate(
//               data['candidate'],
//               data['sdpMid'],
//               data['sdpMLineIndex'],
//             );
//             _peerConnection?.addCandidate(candidate);
//           }
//         }
//       }
//     });
//   }
//
//   Future<void> _hangUp() async {
//     await _peerConnection?.close();
//     await _peerConnection?.dispose();
//     _peerConnection = null;
//
//     if (_localStream != null) {
//       for (var track in _localStream!.getTracks()) {
//         track.stop();
//       }
//       await _localStream?.dispose();
//       _localStream = null;
//     }
//
//     if (_remoteRenderer.srcObject != null) {
//       for (var track in _remoteRenderer.srcObject!.getTracks()) {
//         track.stop();
//       }
//       _remoteRenderer.srcObject = null;
//     }
//
//     await _iceSub?.cancel();
//     _iceSub = null;
//
//     await _callStateSub?.cancel();
//     _callStateSub = null;
//
//     if (_callDocId != null) {
//       final docRef = _firestore.collection('calls').doc(_callDocId);
//       final docSnap = await docRef.get();
//       if (docSnap.exists && docSnap.data()?['callEnded'] != true) {
//         await docRef.update({'callEnded': true});
//       }
//
//       for (final ref in [
//         docRef.collection('callerCandidates'),
//         docRef.collection('calleeCandidates')
//       ]) {
//         final snapshot = await ref.get();
//         for (final doc in snapshot.docs) {
//           await doc.reference.delete();
//         }
//       }
//
//       _callDocId = null;
//     }
//
//     _calleeId = '';         // ✅ Add this line
//     _callDocId = null;      // ✅ Reset call ID
//     _calleeController.clear(); // ✅ Clear input field
//     setState(() {});
//   }
//
//   @override
//   void dispose() {
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     _peerConnection?.dispose();
//     _localStream?.dispose();
//     _iceSub?.cancel();
//     _callStateSub?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final headerColor = const Color(0xFFA58DCA);
//
//     if (_isLoadingProfile) {
//       return Scaffold(
//         appBar: AppBar(title: const Text("Loading Profile...")),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     if (_error != null) {
//       return Scaffold(
//         appBar: AppBar(title: const Text("Error")),
//         body: Center(child: Text(_error!)),
//       );
//     }
//
//     final interestsString = _interests?.join(', ') ?? "Not specified";
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         title: Text("Your Profile", style: TextStyle(color: headerColor)),
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               // Profile Card
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: headerColor.withOpacity(0.8),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: 35,
//                       backgroundColor: Colors.white,
//                       backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
//                           ? NetworkImage(_profileImageUrl!)
//                           : null,
//                       child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
//                           ? Icon(Icons.person, color: headerColor, size: 40)
//                           : null,
//                     ),
//                     const SizedBox(width: 20),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
//                           Text("Age: ${_age ?? 'N/A'}, Gender: ${_gender ?? 'N/A'}", style: TextStyle(color: Colors.white70)),
//                           if (_rating != null)
//                             Row(
//                               children: [
//                                 Icon(Icons.star, color: Colors.white70, size: 16),
//                                 const SizedBox(width: 4),
//                                 Text("${_rating!.toStringAsFixed(1)}", style: TextStyle(color: Colors.white70)),
//                               ],
//                             )
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//               Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text("Interests: $interestsString", style: const TextStyle(fontSize: 16)),
//               ),
//
//               const SizedBox(height: 30),
//
//               // TextField to type UID (optional)
//               const Text("Or enter UID to call:"),
//               TextField(
//                 controller: _calleeController,
//                 onChanged: (value) => _calleeId = value,
//                 decoration: const InputDecoration(hintText: 'Paste another user UID here'),
//               ),
//               const SizedBox(height: 20),
//
//               // Styled Call Button (from MatchMadeProfile)
//               ElevatedButton.icon(
//                 onPressed: () async {
//                   if (_calleeId.trim().isEmpty) {
//                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please enter a Callee UID")));
//                     return;
//                   }
//                   await _startCall(); // 👈 Uses VoiceCallScreen logic
//                 },
//                 icon: const Icon(Icons.call, color: Colors.white),
//                 label: const Text("Start Call", style: TextStyle(color: Colors.white)),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color.fromARGB(255, 159, 134, 192),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
//                   textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//
//               // Show renderer only if audio stream exists
//               if (_remoteRenderer.srcObject != null && _remoteRenderer.srcObject!.getAudioTracks().isNotEmpty)
//                 Column(
//                   children: [
//                     const Text("Remote Audio Stream:"),
//                     SizedBox(width: 120, height: 120, child: RTCVideoView(_remoteRenderer)),
//                   ],
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }