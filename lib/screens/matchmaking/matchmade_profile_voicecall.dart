import 'dart:async';
import 'package:besso_fluently/screens/matchmaking/InCallScreen.dart';
import 'package:besso_fluently/screens/matchmaking/user_chat_request_page.dart';
import 'package:besso_fluently/screens/matchmaking/user_making_call_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class MatchMadeProfile extends StatefulWidget {
  final int userId;

  const MatchMadeProfile({super.key, required this.userId});

  @override
  State<MatchMadeProfile> createState() => _MatchMadeProfileState();
}

class _MatchMadeProfileState extends State<MatchMadeProfile> {
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

  bool _isLoading = true;
  String? _error;
  final Dio _dio = Dio();

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
    _fetchUserData();
    _initRenderers();
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

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final String apiUrl = "http://192.168.1.14:8000/users/${widget.userId}/profile";

    try {
      final response = await _dio.get(apiUrl);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final birthDate = DateTime.tryParse(data['birth_date'] ?? '');
        int? calculatedAge;
        if (birthDate != null) {
          final today = DateTime.now();
          calculatedAge = today.year - birthDate.year;
          if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
            calculatedAge--;
          }
          if (calculatedAge < 0) calculatedAge = null;
        }

        setState(() {
          _fetchedUserId = data['id'];
          _firstName = data['first_name'];
          _lastName = data['last_name'];
          _gender = data['gender'];
          _rating = (data['rating'] as num?)?.toDouble();
          _profileImageUrl = data['profile_image'];
          _interests = (data['interests'] as List?)?.cast<String>();
          _email = data['email'];
          _age = calculatedAge;
          _isLoading = false;
        });
      } else {
        throw Exception("Invalid response from server.");
      }
    } catch (e) {
      setState(() {
        _error = "Failed to fetch profile: $e";
        _isLoading = false;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);
    const Color headerColor = Color(0xFFA58DCA);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: canPop
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: headerColor),
            onPressed: () => Navigator.pop(context),
          )
              : null,
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
          leading: canPop
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: headerColor),
            onPressed: () => Navigator.pop(context),
          )
              : null,
          title: const Text("Error", style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    if (canPop)
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back_ios_new, color: headerColor, size: 24),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        "${_displayName}'s Profile",
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

          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
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
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.white,
                              backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) ? NetworkImage(_profileImageUrl!) : null,
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
                                    "Age: ${_age ?? 'N/A'}${_gender != null && _gender!.isNotEmpty ? ', Gender: $_gender' : ''}",
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_rating != null && _rating! > 0) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.stars, color: Colors.white70, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _rating!.toStringAsFixed(1),
                                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Interests
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Interests: $interestsString",
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Call Button (with username)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_email == null || _email!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("User email not available to start call.")),
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

                        if (firebaseUid != null) {
                          _calleeId = firebaseUid;
                          await _startCall();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Failed to get user UID from Firebase.")),
                          );
                        }
                      },
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: Text(
                        "Call ${_firstName ?? _displayName.split(' ')[0]}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA58DCA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 20), // bottom padding

                    SizedBox(
                      width: 0,
                      height: 0,
                      child: RTCVideoView(_remoteRenderer),
                    ),
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