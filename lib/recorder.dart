import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'dart:typed_data';

class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  AudioRecorderScreenState createState() => AudioRecorderScreenState();
}

class AudioRecorderScreenState extends State<AudioRecorderScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  late Interpreter _interpreter;
  bool _isRecording = false;
  String? _audioPath;
  String? _predictedEmotion;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadModel();
  }

  Future<void> _initRecorder() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      await _recorder.openRecorder();
      _startRecording();
    } else {
      _showPermissionError();
    }
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/voice_insights_model.tflite');
  }

  Future<void> _startRecording() async {
    final path = '${Directory.systemTemp.path}/recorded_audio.wav';
    await _recorder.startRecorder(toFile: path);
    setState(() {
      _isRecording = true;
      _audioPath = path;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });

    if (_audioPath != null) {
      await _analyzeAudio(File(_audioPath!));
    }
  }

  Future<void> _analyzeAudio(File audioFile) async {
    List<double> audioFeatures = await _extractAudioFeatures(audioFile);

    if (audioFeatures.isEmpty) {
      setState(() {
        _predictedEmotion = "Error processing audio";
      });
      return;
    }

    // Prepare model input (reshape if required)
    var input = [audioFeatures]; 
    var output = List<double>.filled(1, 0.0).reshape([1, 1]);

    _interpreter.run(input, output);

    // Convert prediction to emotion label
    String emotion = _getEmotionLabel(output[0][0].toInt());

    setState(() {
      _predictedEmotion = emotion;
    });
  }

  Future<List<double>> _extractAudioFeatures(File audioFile) async {
    final pcmFilePath = '${audioFile.path}.pcm';
    final ffmpeg = FlutterFFmpeg();

    await ffmpeg.execute('-i ${audioFile.path} -f s16le -ac 1 -ar 16000 $pcmFilePath');

    File pcmFile = File(pcmFilePath);
    Uint8List pcmBytes = await pcmFile.readAsBytes();

    // Convert PCM bytes to a list of doubles and normalize
    List<double> audioSamples = pcmBytes.buffer.asInt16List().map((sample) => sample / 32768.0).toList();

    return audioSamples;
  }

  String _getEmotionLabel(int index) {
    const emotions = ['Angry', 'Happy', 'Neutral', 'Sad'];
    return (index >= 0 && index < emotions.length) ? emotions[index] : 'Unknown';
  }

  void _showPermissionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text("Microphone permission is needed to record audio."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Recorder')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isRecording) const Text('Recording...', style: TextStyle(fontSize: 18, color: Colors.red)),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 50),
            color: Colors.red,
            onPressed: _isRecording ? _stopRecording : _startRecording,
          ),
          if (_predictedEmotion != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text("Predicted Emotion: $_predictedEmotion",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:async';
// import 'dart:io';

// class AudioRecorderScreen extends StatefulWidget {
//   const AudioRecorderScreen({super.key});

//   @override
//   AudioRecorderScreenState createState() => AudioRecorderScreenState();
// }

// class AudioRecorderScreenState extends State<AudioRecorderScreen> {
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   final FlutterSoundPlayer _player = FlutterSoundPlayer();

//   bool _isRecording = false;
//   bool _isPaused = false;
//   bool _isPlaying = false;
//   double _playbackProgress = 0.0;
//   String? _audioPath;
//   Timer? _playbackTimer;

//   @override
//   void initState() {
//     super.initState();
//     _initRecorder();
//   }

//   Future<void> _initRecorder() async {
//     var status = await Permission.microphone.request();
//     if (status.isGranted) {
//       await _recorder.openRecorder();
//       _player.openPlayer();
//       _startRecording(); // Automatically start recording after permissions
//     } else {
//       _showPermissionError();
//     }
//   }

//   Future<void> _startRecording() async {
//     final path = '${Directory.systemTemp.path}/my_audio.aac';
//     await _recorder.startRecorder(toFile: path);
//     setState(() {
//       _isRecording = true;
//       _isPaused = false;
//       _audioPath = path;
//     });
//   }

//   Future<void> _pauseRecording() async {
//     await _recorder.pauseRecorder();
//     setState(() {
//       _isPaused = true;
//     });
//   }

//   Future<void> _resumeRecording() async {
//     await _recorder.resumeRecorder();
//     setState(() {
//       _isPaused = false;
//     });
//   }

//   Future<void> _stopRecording() async {
//     await _recorder.stopRecorder();
//     setState(() {
//       _isRecording = false;
//       _isPaused = false;
//     });
//   }

//   Future<void> _playRecording() async {
//     if (_audioPath != null) {
//       await _player.startPlayer(
//         fromURI: _audioPath!,
//         whenFinished: () {
//           setState(() {
//             _isPlaying = false;
//             _playbackProgress = 0.0;
//           });
//           _playbackTimer?.cancel();
//         },
//       );

//       setState(() {
//         _isPlaying = true;
//         _playbackProgress = 0.0;
//       });

//       _playbackTimer =
//           Timer.periodic(const Duration(milliseconds: 200), (timer) {
//         if (_player.isPlaying) {
//           setState(() {
//             _playbackProgress += 0.02;
//           });
//         } else {
//           timer.cancel();
//         }
//       });
//     }
//   }

//   Future<void> _pausePlayback() async {
//     await _player.pausePlayer();
//     setState(() {
//       _isPlaying = false;
//     });
//   }

//   Future<void> _resumePlayback() async {
//     await _player.resumePlayer();
//     setState(() {
//       _isPlaying = true;
//     });
//   }

//   Future<void> _stopPlayback() async {
//     await _player.stopPlayer();
//     setState(() {
//       _isPlaying = false;
//       _playbackProgress = 0.0;
//     });
//     _playbackTimer?.cancel();
//   }

//   void _showPermissionError() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Permission Required"),
//         content: const Text("Microphone permission is needed to record audio."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text("OK"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _recorder.closeRecorder();
//     _player.closePlayer();
//     _playbackTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Audio Recorder')),
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           if (_isRecording) ...[
//             Text('Recording...',
//                 style: TextStyle(fontSize: 18, color: Colors.red)),
//             SizedBox(height: 8),
//             _blinkingIndicator(),
//           ],
//           if (_isPlaying)
//             Padding(
//               padding: EdgeInsets.symmetric(vertical: 16),
//               child: Column(
//                 children: [
//                   Text('Playing...',
//                       style: TextStyle(fontSize: 18, color: Colors.blue)),
//                   LinearProgressIndicator(value: _playbackProgress),
//                 ],
//               ),
//             ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 50),
//                 color: Colors.red,
//                 onPressed: _isRecording ? _stopRecording : _startRecording,
//               ),
//               if (_isRecording)
//                 IconButton(
//                   icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause,
//                       size: 50),
//                   color: Colors.orange,
//                   onPressed: _isPaused ? _resumeRecording : _pauseRecording,
//                 ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 icon:
//                     Icon(_isPlaying ? Icons.stop : Icons.play_arrow, size: 50),
//                 color: Colors.blue,
//                 onPressed: _isPlaying ? _stopPlayback : _playRecording,
//               ),
//               if (_isPlaying)
//                 IconButton(
//                   icon: Icon(Icons.pause, size: 50),
//                   color: Colors.orange,
//                   onPressed: _pausePlayback,
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _blinkingIndicator() {
//     return TweenAnimationBuilder(
//       tween: Tween<double>(begin: 0.2, end: 1.0),
//       duration: Duration(milliseconds: 500),
//       builder: (context, double opacity, child) {
//         return Opacity(
//           opacity: _isRecording ? opacity : 0.0,
//           child: Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
//         );
//       },
//       onEnd: () {
//         if (_isRecording) {
//           setState(() {});
//         }
//       },
//     );
//   }
// }
