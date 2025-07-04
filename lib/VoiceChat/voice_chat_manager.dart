import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class VoiceChatManager {
  final String token;
  final String roomId;
  final String host;
  final Function(String transcript, String label) onAnalysis;

  FlutterSoundRecorder? _recorder;
  final List<int> _analysisBuffer = [];
  Timer? _analysisTimer;
  late StreamController<Uint8List> _audioStreamController;

  VoiceChatManager({
    required this.token,
    required this.roomId,
    required this.host,
    required this.onAnalysis,
  });

  Future<void> initRecorder() async {
    await Permission.microphone.request();
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<void> startRecording() async {
    const int sampleRate = 16000;

    _audioStreamController = StreamController<Uint8List>();

    await _recorder!.startRecorder(
      codec: Codec.pcm16,
      sampleRate: sampleRate,
      numChannels: 1,
      toStream: _audioStreamController.sink,
    );

    _audioStreamController.stream.listen((Uint8List data) {
      _analysisBuffer.addAll(data);

      // Flush if we have enough for 5 seconds
      if (_analysisBuffer.length >= sampleRate * 5 * 2) {
        _flushAudioForAnalysis();
      }
    });

    // 🔁 Always flush buffer every 5 seconds, even if under threshold
    _analysisTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _flushAudioForAnalysis();
    });
  }

  Future<void> startRecordingWithStreaming(Function(Uint8List) onStreamData) async {
    const int sampleRate = 16000;
    _audioStreamController = StreamController<Uint8List>();

    await _recorder!.startRecorder(
      codec: Codec.pcm16,
      sampleRate: sampleRate,
      numChannels: 1,
      toStream: _audioStreamController.sink,
    );

    _audioStreamController.stream.listen((Uint8List data) {
      _analysisBuffer.addAll(data);

      // Send real-time chunk for voice chat
      onStreamData(data);

      // Flush for analysis every 5 sec of data
      if (_analysisBuffer.length >= sampleRate * 5 * 2) {
        _flushAudioForAnalysis();
      }
    });

    _analysisTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _flushAudioForAnalysis();
    });
  }


  void _flushAudioForAnalysis() async {
    if (_analysisBuffer.isEmpty) return;

    final wav = convertToWav(_analysisBuffer);
    _analysisBuffer.clear();
    await _sendForAnalysis(wav);
  }

  Future<void> _sendForAnalysis(Uint8List wavData) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://$host:8001/analyze-audio'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      wavData,
      filename: 'audio.wav',
    ));

    try {
      final response = await request.send();
      final result = await http.Response.fromStream(response);

      if (result.statusCode == 200) {
        final json = jsonDecode(result.body);
        onAnalysis(json['transcript'], json['label']);
      } else {
        print("❌ Analysis failed: ${result.statusCode} — ${result.body}");
      }
    } catch (e) {
      print("❌ Error sending audio for analysis: $e");
    }
  }

  Uint8List convertToWav(List<int> samples, {int sampleRate = 16000}) {
    final int byteRate = sampleRate * 2;
    final buffer = BytesBuilder();

    buffer.add(ascii.encode('RIFF'));
    buffer.add(_int32ToBytes(36 + samples.length));
    buffer.add(ascii.encode('WAVE'));
    buffer.add(ascii.encode('fmt '));
    buffer.add(_int32ToBytes(16));
    buffer.add(_int16ToBytes(1));
    buffer.add(_int16ToBytes(1));
    buffer.add(_int32ToBytes(sampleRate));
    buffer.add(_int32ToBytes(byteRate));
    buffer.add(_int16ToBytes(2));
    buffer.add(_int16ToBytes(16));
    buffer.add(ascii.encode('data'));
    buffer.add(_int32ToBytes(samples.length));

    for (final sample in samples) {
      buffer.add(_int16ToBytes(sample));
    }

    return buffer.toBytes();
  }

  Uint8List _int16ToBytes(int value) => Uint8List(2)..buffer.asByteData().setInt16(0, value, Endian.little);
  Uint8List _int32ToBytes(int value) => Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.little);

  Future<void> stop() async {
    await _recorder?.stopRecorder();
    await _audioStreamController.close();
    _analysisTimer?.cancel();

    // 🔥 Flush remaining audio (even if less than 5 sec)
    _flushAudioForAnalysis();
  }

}
