import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/Ip_provider.dart';
import '/utils/firestore_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'after_call_page.dart';
import 'matchmaking_page.dart';

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

  final _recorder = Record();
  Timer? _recordingTimer;
  bool _isRecording = false;
  int offensiveCount = 0;
  bool callTerminatedDueToDetection = false;




  static const double headerHeight = 60.0;

  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    listenToCallEnd();
    _requestMicPermissionAndStartRecording();
  }

  Future<void> _requestMicPermissionAndStartRecording() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _startRecordingLoop();
    } else {
      print("❌ Microphone permission denied");
    }
  }

  void _startRecordingLoop() async {
    final tempDir = await getTemporaryDirectory();

    _recordingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isRecording) {
        final path = await _recorder.stop();
        _isRecording = false;

        if (path != null) {
          await _sendAudioToBackend(path);
        }
      }

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final fullPath = p.join(tempDir.path, fileName);

      await _recorder.start(
        path: fullPath,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 16000,
      );

      _isRecording = true;
    });
  }

  Future<void> _sendAudioToBackend(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final dio = Dio();

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'chunk.m4a'),
      });

      final response = await dio.post(
        'http://${IpAddress}:8001/analyze-audio',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final String result = response.data['result'] ?? '';

      if (result.toLowerCase() == 'hate') {
        print("⚠️ Hate speech detected. Terminating call.");
        await _terminateCallDueToViolation(reason: "Hate speech");
      } else if (result.toLowerCase() == 'offensive') {
        offensiveCount++;
        print("⚠️ Offensive speech detected. Count: $offensiveCount");

        if (offensiveCount >= 3) {
          print("⚠️ Offensive speech limit reached. Terminating call.");
          await _terminateCallDueToViolation(reason: "Repeated offensive speech");
        }
      }
    } catch (e) {
      print("❌ Error sending audio: $e");
    }
  }

  Future<void> _terminateCallDueToViolation({required String reason}) async {
    if (callTerminatedDueToDetection) return;

    callTerminatedDueToDetection = true;
    print("🚫 Ending call due to: $reason");

    if (_callDocId != null) {
      await _firestore.collection('calls').doc(_callDocId).update({
        'callEnded': true,
        'callEndedBy': widget.selfId,
      });
    }

    await _recorder.stop();
    _recordingTimer?.cancel();
    await widget.hangUp();
    await updateCallDurationToBackend();

    if (_otherUserId != null) {
      final otherUserId = await getBackendUserIdFromFirebaseUid(_otherUserId!);

      if (mounted) {
        if (otherUserId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AfterCallPage(userId: otherUserId),
              ),
            );
          });
        } else {
          print("⚠️ Could not resolve otherUserId");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/friends');
          });
        }
      }
    } else {
      print("⚠️ _otherUserId is null");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
    }
  }

  Future<void> updateCallDurationToBackend() async {
    if (_callStartTime == null) return;

    final callEndTime = DateTime.now();
    final duration = callEndTime.difference(_callStartTime!);
    final int minutes = duration.inMinutes;

    if (minutes == 0) {
      print("⚠️ Call duration is less than 1 minute. Skipping backend update.");
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
            _recordingTimer?.cancel();
            await _recorder.stop();
            await widget.hangUp();
            await updateCallDurationToBackend();

          }
        });
        break;
      }
    }
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
    _recordingTimer?.cancel();
    _recorder.dispose();
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
              offset: const Offset(0, -50),
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