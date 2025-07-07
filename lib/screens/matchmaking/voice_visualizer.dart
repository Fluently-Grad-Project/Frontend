// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class VoiceVisualizer extends StatefulWidget {
//   const VoiceVisualizer({super.key});
//
//   @override
//   State<VoiceVisualizer> createState() => _VoiceVisualizerState();
// }
//
// class _VoiceVisualizerState extends State<VoiceVisualizer> {
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   double _volume = 0.0;
//
//   @override
//   void initState() {
//     super.initState();
//     _initRecorder();
//   }
//
//   Future<void> _initRecorder() async {
//     final micStatus = await Permission.microphone.request();
//     if (!micStatus.isGranted) {
//       print("❌ Microphone permission denied");
//       return;
//     }
//
//     await _recorder.openRecorder();
//
//     await _recorder.startRecorder(
//       toStream: null,
//       codec: Codec.pcm16,
//       sampleRate: 44000,
//       numChannels: 1,
//       bitRate: 16000,
//       audioSource: AudioSource.microphone,
//       onProgress: (event) {
//         final decibels = event.decibels;
//         if (decibels != null && mounted) {
//           setState(() {
//             _volume = decibels;
//           });
//         }
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     _recorder.stopRecorder();
//     _recorder.closeRecorder();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final normalized = (_volume + 50).clamp(0, 60);
//     final height = normalized * 2;
//
//     return Column(
//       children: [
//         Text(
//           "Volume: ${_volume.toStringAsFixed(1)} dB",
//           style: const TextStyle(fontSize: 14),
//         ),
//         const SizedBox(height: 10),
//         SizedBox(
//           height: 120,
//           child: Center(
//             child: SizedBox(
//               width: 220,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: List.generate(20, (i) {
//                   final barHeight = (height * ((i % 5 + 1) / 5)).clamp(10, 100).toDouble();
//                   return AnimatedContainer(
//                     duration: const Duration(milliseconds: 100),
//                     width: 5,
//                     height: barHeight,
//                     decoration: BoxDecoration(
//                       color: Colors.purpleAccent,
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                   );
//                 }),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
