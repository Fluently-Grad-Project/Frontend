import 'dart:async';
import 'package:record/record.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';  // Make sure you have flutter_webrtc imported
import 'package:shared_preferences/shared_preferences.dart';


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
  final Record _recorder = Record();
  Timer? _recordTimer;
  StreamSubscription<DocumentSnapshot>? _callSub;
  String? _callDocId;
  String? _otherUserId;
  String _otherUserName = 'Voice Chat';
  String? _jwtToken;
  DateTime? _callStartTime;
  DateTime? _callEndTime;



  Dio _dio = Dio();

  static const double headerHeight = 60.0;

  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadJwtToken(); // 👇 load it first
    listenToCallEnd();
    startAudioRecordingLoop();
    _callStartTime = DateTime.now();
  }


  Future<void> _loadJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _jwtToken = prefs.getString('token');
    });
  }


  Future<void> startAudioRecordingLoop() async {
    print("🎙️ Starting audio recording loop...");

    final hasPermission = await _recorder.hasPermission();
    print("🔐 Microphone permission: $hasPermission");

    if (!hasPermission) return;

    _recordTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      print("⏱ Recording cycle triggered...");

      if (await _recorder.isRecording()) {
        print("🛑 Stopping current recording...");
        final filePath = await _recorder.stop();

        if (filePath != null) {
          print("📤 Sending audio file: $filePath");
          await sendAudioToBackend(File(filePath));
        }
      }

      final tempDir = await getTemporaryDirectory();
      final newFilePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      print("🎬 Starting new recording: $newFilePath");

      await _recorder.start(
        path: newFilePath,
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        samplingRate: 16000,
      );
    });
  }

  Future<void> sendAudioToBackend(File audioFile) async {
    try {
      print("📡 Sending audio to backend...");

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFile.path, filename: 'clip.wav'),
      });

      final response = await _dio.post(
        'http://192.168.1.53:8001/analyze-audio',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
          },
        ),
      );

      print("✅ Audio sent successfully: ${response.statusCode} - ${response.data}");

      // ✅ Delete file safely after successful upload
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
          print("🧹 Temp file deleted: ${audioFile.path}");
        }
      } catch (e) {
        print("⚠️ Failed to delete temp file: $e");
      }

    } catch (e) {
      print("❌ Error sending audio to backend: $e");
    }
  }

  Future<void> sendCallDuration() async {
    if (_callStartTime == null) return;

    _callEndTime = DateTime.now();
    final duration = _callEndTime!.difference(_callStartTime!);
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    print("🕒 Call duration: $hours hours, $minutes minutes");

    try {
      final response = await _dio.patch(
        'http://192.168.1.53:8000/activity/update_hours',
        data: {
          'hours_to_add': hours,
          'minutes': minutes,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
          },
        ),
      );

      print("✅ Call duration sent: ${response.statusCode}");
    } catch (e) {
      print("❌ Failed to send call duration: $e");
    }
  }


  Future<void> stopRecordingLoop() async {
    print("🛑 Stopping audio recording loop...");
    _recordTimer?.cancel();
    _recordTimer = null;

    if (await _recorder.isRecording()) {
      print("🛑 Stopping final recording...");
      await _recorder.stop();
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

        // ✅ Set the other user's ID
        if (data['callerId'] == widget.selfId) {
          _otherUserId = data['calleeId'];
        } else {
          _otherUserId = data['callerId'];
        }

        // ✅ Fetch the other user's name
        await _fetchOtherUserName();

        // ✅ Listen for callEnded
        _callSub = _firestore
            .collection('calls')
            .doc(_callDocId)
            .snapshots()
            .listen((snapshot) async {
          final callData = snapshot.data();
          if (callData != null && callData['callEnded'] == true) {
            print("📴 Remote user ended call (fallback listener)");
            await sendCallDuration();
            await widget.hangUp();
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });

        break; // stop after finding first match
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
    stopRecordingLoop();
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
                await sendCallDuration();
                await widget.hangUp();
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
