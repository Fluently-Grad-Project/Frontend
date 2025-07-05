import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


class AudioChatScreen extends StatefulWidget {
  @override
  _AudioChatScreenState createState() => _AudioChatScreenState();
}

class _AudioChatScreenState extends State<AudioChatScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        print("Microphone permission not granted");
        return;
      }

      await _recorder.startRecorder(toFile: 'audio_recording.aac');
      setState(() => _isRecording = true);
    } catch (e) {
      print("Recording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? path = await _recorder.stopRecorder();
      if (path != null) {
        await _sendAudioToServer(path);
      }
      setState(() => _isRecording = false);
    } catch (e) {
      print("Stop recording error: $e");
    }
  }

  Future<void> _sendAudioToServer(String audioPath) async {
    setState(() => _isLoading = true);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.53:3000/api/chat'),
      );

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioPath,
        contentType: MediaType('audio', 'aac'),
      ));

      // Send request
      var response = await request.send();

      if (response.statusCode == 200) {
        // Get response as bytes
        Uint8List responseBytes = await response.stream.toBytes();

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final responsePath = '${tempDir.path}/ai_response.wav';
        File(responsePath).writeAsBytesSync(responseBytes);

        // Play the response
        await _audioPlayer.setFilePath(responsePath);
        await _audioPlayer.play();
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('API error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pronunciation Helper')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              CircularProgressIndicator()
            else
              IconButton(
                iconSize: 80,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
            SizedBox(height: 20),
            Text(_isRecording ? 'Recording...' : 'Tap to record'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }
}