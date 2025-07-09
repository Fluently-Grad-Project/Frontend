import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/utils/firestore_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'after_call_page.dart';  // Make sure you have flutter_webrtc imported
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class InCallScreen extends StatefulWidget {
  final Future<void> Function() hangUp;
  final String selfId;

  const InCallScreen({
    super.key,
    required this.hangUp,
    required this.selfId,
  });

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _callSub;
  String? _callDocId;
  String? _otherUserId;
  String _otherUserName = 'Voice Chat';
  DateTime? _callStartTime;

  final Record _recorder = Record();
  Timer? _uploadTimer;
  String? _currentRecordingPath;



  static const double headerHeight = 60.0;

  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    listenToCallEnd();
    startRecordingAndUploadTimer(); // ⬅️ Start audio recording & periodic uploads
  }


  Future<void> startRecordingAndUploadTimer() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      print("❌ Microphone permission denied");
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _currentRecordingPath = path;

    await _recorder.start(
      path: path,
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      samplingRate: 44100,
    );

    print("🎙️ Recording started at $path");

    _uploadTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _uploadAudioToBackend();
      // Don't call startRecordingAndUploadTimer again — just restart with a new file:
      await _restartRecording();
    });
  }

  Future<void> _restartRecording() async {
    await _recorder.stop();

    final dir = await getTemporaryDirectory();
    final newPath = p.join(
      dir.path,
      'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _currentRecordingPath = newPath;

    await _recorder.start(
      path: newPath,
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      samplingRate: 44100,
    );

    print("🎙️ Recording restarted at $newPath");
  }


  Future<void> _uploadAudioToBackend() async {
    if (_currentRecordingPath == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    final file = MultipartFile.fromFileSync(_currentRecordingPath!, filename: 'audio.m4a');
    final formData = FormData.fromMap({
      'file': file,
    });

    try {
      final dio = Dio();
      final response = await dio.post(
        'http://localhost:8001/analyze-audio',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print("✅ Audio uploaded: ${response.data}");
    } catch (e) {
      print("❌ Audio upload failed: $e");
    }
  }


  Future<void> updateCallDurationToBackend() async {
    if (_callStartTime == null) return;

    final callEndTime = DateTime.now();
    final duration = callEndTime.difference(_callStartTime!);
    final int minutes = duration.inMinutes;

    // ✅ Skip if duration is negative or zero
    if (minutes <= 0) {
      print("⚠️ Call duration is less than or equal to 0 minutes. Skipping backend update.");
      return;
    }

    print("⏱️ Call lasted $minutes minute(s). Sending to backend...");

    final dio = Dio();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final response = await dio.patch(
        'http://192.168.1.14:8000/activity/update_hours',
        data: {
          'hours_to_add': 0,
          'minutes': minutes,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print("✅ Call duration sent to backend: ${response.data}");
    } catch (e) {
      if (e is DioException && e.response != null) {
        print("❌ Server responded with: ${e.response?.data}");
      }
      print("❌ Failed to update activity hours: $e");
    }
  }

  Future<void> listenToCallEnd() async {
    final query = await _firestore
        .collection('calls')
        .where('callEnded', isEqualTo: false)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      if (data['callerId'] == widget.selfId || data['calleeId'] == widget.selfId) {
        _callDocId = doc.id;

        // ✅ Store _otherUserId immediately
        _otherUserId = data['callerId'] == widget.selfId
            ? data['calleeId']
            : data['callerId'];

        _fetchOtherUserName(); // ✅ Fetch username early

        _callSub = _firestore
            .collection('calls')
            .doc(_callDocId)
            .snapshots()
            .listen((snapshot) async {
          final callData = snapshot.data();

          if (callData != null && callData['callEnded'] == true) {
            print("📴 Remote user ended call");

            if (_otherUserId == null) {
              print("⚠️ _otherUserId is still null");
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              return;
            }

            if (_otherUserId != null) {
              final otherUserId = await getBackendUserIdFromFirebaseUid(_otherUserId!);

              if (otherUserId != null) {
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AfterCallPage(userId: otherUserId),
                      ),
                    );
                  });
                }
              } else {
                print("⚠️ otherUserId is null");
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacementNamed('/friends');
                  });
                }
              }
            }

            // cleanup AFTER navigation
            await widget.hangUp();
            await updateCallDurationToBackend();
            await _stopRecordingAndUploads();
          }
        });
        break;
      }
    }
  }

  Future<void> _stopRecordingAndUploads() async {
    _uploadTimer?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    print("🛑 Recording stopped.");
  }


  Future<void> _fetchOtherUserName() async {
    if (_otherUserId == null) {
      print("No other user ID found");
      return;
    }
    print("Fetching username for user id: $_otherUserId");

    final query = await _firestore
        .collection('users')
        .where('uid', isEqualTo: _otherUserId)
        .limit(1)
        .get();

    print("User query returned docs: ${query.docs.length}");
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      print("User document data: $data");
      final username = data['username'] ?? '';
      setState(() {
        _otherUserName = username.isNotEmpty ? username : 'Unknown User';
      });
    } else {
      print("No user found with uid=$_otherUserId");
      setState(() {
        _otherUserName = 'Unknown User';
      });
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  double topSpacingHeight = 35.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'User Call',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),
      body: Container(
        color: const Color(0xFFEDECEE),
        width: double.infinity,
        child: Column(
          children: [
            // Header bar with user info
            Container(
              width: double.infinity,
              height: headerHeight,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x6E9F86C0),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/caller-icon.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Big centered call AI icon, moved upward
            Transform.translate(
              offset: const Offset(0, -40),
              child: Center(
                child: Image.asset(
                  'assets/call-ai-icon.png',
                  width: 290,
                  height: 290,
                ),
              ),
            ),

            // End call button below the big icon
            GestureDetector(
              onTap: () async {
                if (_callDocId != null) {
                  await _firestore.collection('calls').doc(_callDocId).update({
                    'callEnded': true,
                    'callEndedBy': widget.selfId,
                  });
                }

                // await Future.delayed(const Duration(milliseconds: 300));
                //
                // if (_otherUserId != null) {
                //   final otherUserId = await getBackendUserIdFromFirebaseUid(_otherUserId!);
                //   print(" getbackenduserid return function _otherUserId");
                //   print(otherUserId);
                //   print("this is mounted");
                //   print(mounted);
                //
                //   if (!mounted) {
                //     print("❌ Widget is no longer mounted. Skipping navigation.");
                //     return;
                //   }
                //
                //   if (otherUserId != null) {
                //     // ✅ Defer navigation safely to the next frame
                //     WidgetsBinding.instance.addPostFrameCallback((_) {
                //       Navigator.of(context).pushReplacement(
                //         MaterialPageRoute(
                //           builder: (_) => AfterCallPage(userId: otherUserId),
                //         ),
                //       );
                //     });
                //   } else {
                //     print("⚠️ otherUserId is null");
                //     WidgetsBinding.instance.addPostFrameCallback((_) {
                //       Navigator.of(context).pushReplacementNamed('/friends');
                //     });
                //   }
                // } else {
                //   print("⚠️ _otherUserId is null, cannot navigate.");
                //   if (mounted) {
                //     WidgetsBinding.instance.addPostFrameCallback((_) {
                //       Navigator.of(context).popUntil((route) => route.isFirst);
                //     });
                //   }
                // }
                //
                // // ✅ Cleanup AFTER navigation has started
                // await widget.hangUp();
                // await updateCallDurationToBackend();
              },
              child: Center(
                child: Image.asset(
                  'assets/end-call-icon.png',
                  width: 130,
                  height: 130,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}