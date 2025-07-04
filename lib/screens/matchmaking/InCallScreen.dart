import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:vibration/vibration.dart';
import '../../VoiceChat/voice_chat_manager.dart';
import 'after_call_page.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '/VoiceChat/call_signaling_manager.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';

class InCallScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String roomId;

  const InCallScreen(
      {Key? key, required this.userId, required this.userName, required this.roomId})
      : super(key: key);

  @override
  State<InCallScreen> createState() => _InCallScreenState();

  static const double headerHeight = 60.0;
}
class _InCallScreenState extends State<InCallScreen> {
  WebSocket? voiceSocket;
  Stream<List<int>>? audioStream;

  late StreamSubscription<List<int>> _micStreamSubscription;
  late StreamController<Uint8List> _audioStreamController;
  late VoiceChatManager voiceChatManager;

  FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlayerInited = false;


  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  FlutterSoundRecorder? _recorder;

  @override
  void initState() {
    super.initState();

    _player.openPlayer().then((_) {
      setState(() {
        _isPlayerInited = true;
      });
    });

    _startCall();
  }

  Future<void> _startCall() async {
    final bool isCaller = ModalRoute.of(context)!.settings.arguments as bool;

    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };

    _peerConnection = await createPeerConnection(config);
    _peerConnection!.addStream(_localStream!);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        CallSignalingManager.instance.sendIceCandidate(candidate, widget.roomId);
      }
    };

    _peerConnection!.onAddStream = (stream) {
      print("Remote stream received");
    };

    CallSignalingManager.instance.onRemoteDescription = (description) async {
      await _peerConnection!.setRemoteDescription(description);

      if (!isCaller) {
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        CallSignalingManager.instance.sendAnswer(
          widget.roomId,
          RTCSessionDescription(answer.sdp, answer.type),
        );
      }
    };

    CallSignalingManager.instance.onRemoteIceCandidate = (candidate) async {
      await _peerConnection!.addCandidate(candidate);
    };

    // ✅ Only caller sends the offer
    if (isCaller) {
      await CallSignalingManager.instance.startVoiceChat(widget.roomId, _peerConnection!);
    }

    await _connectToVoiceSocket();
  }

  Future<void> _connectToVoiceSocket() async {
    final token = CallSignalingManager.instance.token; // Assuming you stored the user token there
    final uri = 'ws://192.168.1.53:8000/ws/start_voice_chat/${widget.roomId}?token=$token';

    try {
      voiceSocket = await WebSocket.connect(uri);
      print('[VoiceSocket] Connected ✅');

      // Listen for incoming data from the other user
      // OLD:
      // ✅ NEW:
      voiceSocket!.listen((data) {
        if (data is List<int>) {
          try {
            final message = utf8.decode(data);
            if (message == "END_CALL") {
              print("Call ended by other user");
              _hangUpAndNavigate();
              return;
            }
          } catch (_) {
            // Not a UTF8 string — must be raw audio
          }

          _playAudio(Uint8List.fromList(data)); // ✅ Play audio
        }
      });
      // Start capturing mic audio and sending it
      voiceChatManager = VoiceChatManager(
        token: token,
        roomId: widget.roomId,
        host: '192.168.1.53', // Your backend analyzer host
        onAnalysis: (transcript, label) {
          print("📢 Transcript: $transcript | Label: $label");
        },
      );
      // Store it so you can stop it later
      await voiceChatManager.initRecorder();

      voiceChatManager.startRecordingWithStreaming((Uint8List data) {
        voiceSocket?.add(data); // 🔁 Send mic data to WebSocket for real-time voice
      });

    } catch (e) {
      print("Voice socket connection error: $e");
    }
  }

  void _playAudio(Uint8List audioData) async {
    if (!_isPlayerInited) return;

    try {
      await _player.startPlayer(
        fromDataBuffer: audioData,
        codec: Codec.pcm16, // or Codec.opus depending on your server
        sampleRate: 16000,
        numChannels: 1,
      );
    } catch (e) {
      print("🔇 Error playing audio: $e");
    }
  }


  void _hangUpAndNavigate() async {
    await voiceChatManager.stop(); // ✅ Stop and flush audio
    await _recorder?.stopRecorder();
    await _recorder?.closeRecorder();
    voiceSocket?.close();
    _peerConnection?.close();
    _localStream?.dispose();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AfterCallPage(userId: widget.userId),
      ),
    );
  }

  @override
  void dispose() {
    voiceChatManager.stop(); // ✅ Clean up when widget is destroyed
    _recorder?.stopRecorder();
    _recorder?.closeRecorder();
    voiceSocket?.close();
    _peerConnection?.close();
    _localStream?.dispose();
    _player.closePlayer(); // ✅ Cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 60.0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'User Call',
          style: TextStyle(fontSize: 18, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: const Color(0xFFEDECEE),
        width: double.infinity,
        child: Column(
          children: [
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
                  Image.asset('assets/caller-icon.png', width: 40, height: 40),
                  const SizedBox(width: 10),
                  Text(
                    widget.userName,
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
            GestureDetector(
              onTap: () async {
                if (await Vibration.hasVibrator() ?? false) {
                  Vibration.vibrate(duration: 200);
                }

                // Send END_CALL signal to backend
                voiceSocket?.add(utf8.encode("END_CALL"));

                // Stop and dispose everything
                await _recorder?.stopRecorder();
                await _recorder?.closeRecorder();
                voiceSocket?.close();
                _peerConnection?.close();
                _localStream?.dispose();

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AfterCallPage(userId: widget.userId),
                  ),
                );
              },
              child: Center(
                child: Image.asset('assets/end-call-icon.png', width: 130, height: 130),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
