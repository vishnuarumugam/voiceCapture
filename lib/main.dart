import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:whisper_flutter_new/whisper_flutter_new.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OfflineVoiceApp());
}

class OfflineVoiceApp extends StatelessWidget {
  const OfflineVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Capture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VoiceHomePage(),
    );
  }
}

class VoiceHomePage extends StatefulWidget {
  const VoiceHomePage({super.key});

  @override
  State<VoiceHomePage> createState() => _VoiceHomePageState();
}

class _VoiceHomePageState extends State<VoiceHomePage> {
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();

  Whisper? _whisper;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _lastRecordingPath = "";
  String _transcription = "";

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _initTts();
    _initWhisper();
  }

  Future<void> _initPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _initTts() async {
    // Adjust as you like
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setLanguage("en-US");
  }

  Future<void> _initWhisper() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = '${dir.path}/whisper_models';

    // Make sure directory exists
    await Directory(modelDir).create(recursive: true);

    // IMPORTANT: Model must be named exactly as Whisper expects (ggml-tiny.bin)
    final modelPath = '$modelDir/ggml-tiny.bin';

    if (!File(modelPath).existsSync()) {
      final data = await rootBundle.load('assets/models/ggml-tiny.bin');
      await File(
        modelPath,
      ).writeAsBytes(data.buffer.asUint8List(), flush: true);
      debugPrint("Local model copied to: $modelPath");
    }

    // Initialize Whisper (offline, no download)
    _whisper = Whisper(
      model: WhisperModel.tiny, // use enum
      modelDir: modelDir, // folder containing ggml-tiny.bin
      downloadHost: null, // ❌ disable download
    );

    debugPrint("Whisper model directory: $modelDir");
  }

  Future<String> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception("Microphone permission not granted");

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );

    debugPrint("Recorded file: $filePath");
    debugPrint("File size: ${File(filePath).lengthSync()} bytes");
    return filePath;
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
  }

  Future<void> _toggleRecordAndTranscribe() async {
    if (_isRecording) {
      // Stop and transcribe
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      await _stopRecording();

      try {
        await _runWhisperOnFile(_lastRecordingPath);
      } catch (e) {
        debugPrint('Transcription error: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isTranscribing = false;
          });
        }
      }
    } else {
      // Start recording
      try {
        final path = await _startRecording();
        setState(() {
          _lastRecordingPath = path;
          _transcription = "";
          _isRecording = true;
        });
      } catch (e) {
        debugPrint('Recording error: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
        }
      }
    }
  }

  Future<void> _runWhisperOnFile(String wavPath) async {
    if (_whisper == null) {
      throw Exception("Whisper not initialized");
    }

    final response = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        language: "auto", // or "en", "hi", etc.
        isTranslate: false, // if true, translate to English
        isNoTimestamps: true,
        splitOnWord: false,
      ),
    );

    final processedText =
        "Danke, I understand that you ask ${response.text.toLowerCase()}";

    setState(() {
      _transcription = processedText;
    });
  }

  Future<void> _speak() async {
    if (_transcription.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(_transcription);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isTranscribing;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Capture')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: isBusy ? null : _toggleRecordAndTranscribe,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(
                  _isRecording ? "Stop & Transcribe" : "Record & Transcribe",
                ),
              ),
              const SizedBox(height: 16),
              if (_isTranscribing) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text("Transcribing..."),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Transcription:",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _transcription.isEmpty
                          ? "No text yet. Tap Record & Transcribe and start speaking."
                          : _transcription,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _transcription.isEmpty ? null : _speak,
                  icon: const Icon(Icons.volume_up),
                  label: const Text("Speak (TTS)"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
