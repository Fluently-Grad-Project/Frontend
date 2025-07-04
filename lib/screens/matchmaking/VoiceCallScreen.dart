// import 'dart:async';
// import 'package:besso_fluently/screens/matchmaking/user_chat_request_page.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'InCallScreenOld.dart';
//
// class VoiceCallScreen extends StatefulWidget {
//   const VoiceCallScreen({super.key});
//
//   @override
//   State<VoiceCallScreen> createState() => _VoiceCallScreenState();
// }
//
// class _VoiceCallScreenState extends State<VoiceCallScreen> {
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
//   @override
//   void initState() {
//     super.initState();
//     initRenderers();
//     setupCallListener();
//   }
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
//             // 👇 Accept button returns true, so we handle the answer here
//             if (result == true) {
//               await _answerCall(dataWithId);
//             } else {
//               // 🧹 Reset state if call was declined or cancelled
//               _calleeId = '';
//               _calleeController.clear();
//               setState(() {});
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
//     return Scaffold(
//       appBar: AppBar(title: const Text('Voice Call')),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               const Text("Enter Callee ID (User UID):"),
//               TextField(
//                 controller: _calleeController,
//                 onChanged: (value) => _calleeId = value,
//                 decoration: const InputDecoration(hintText: 'Paste another user UID here'),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(onPressed: _startCall, child: const Text("Start Call")),
//               const SizedBox(height: 20),
//               Text("Your UID:\n$_selfId"),
//               if (_remoteRenderer.srcObject != null &&
//                   _remoteRenderer.srcObject!.getAudioTracks().isNotEmpty)
//                 Column(
//                   children: [
//                     const SizedBox(height: 20),
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