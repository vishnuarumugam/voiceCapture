import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpeechToTextApp());
}

class SpeechToTextApp extends StatelessWidget {
  const SpeechToTextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conversational Voice App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const SpeechConversationScreen(),
    );
  }
}

class SpeechConversationScreen extends StatefulWidget {
  const SpeechConversationScreen({super.key});

  @override
  _SpeechConversationScreenState createState() =>
      _SpeechConversationScreenState();
}

class _SpeechConversationScreenState extends State<SpeechConversationScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _inCall = false;
  List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTTS();
  }

  Future<void> _initSpeech() async {
    await Permission.microphone.request();
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) => debugPrint('Speech Status: $status'),
      onError: (error) => debugPrint('Speech Error: $error'),
    );
    setState(() {});
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
  }

  void _startCall() {
    setState(() => _inCall = true);
    _startListening();
  }

  void _endCall() {
    _speechToText.stop();
    _flutterTts.stop();
    setState(() {
      _isListening = false;
      _inCall = false;
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) return;

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3), // Increased buffer
      partialResults: true,
    );

    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  void _onSpeechResult(SpeechRecognitionResult result) async {
    if (result.finalResult) {
      final spokenText = result.recognizedWords;
      if (spokenText.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500)); // buffer wait
        setState(() {
          _messages.add({"role": "user", "text": spokenText});
        });
        _handleBotResponse(spokenText);
      }
    }
  }

  void _handleBotResponse(String userInput) async {
    final botReply = "Danke, I understand you ask that $userInput";

    setState(() {
      _messages.add({"role": "bot", "text": botReply});
    });

    await _flutterTts.speak(botReply);

    _flutterTts.setCompletionHandler(() async {
      await Future.delayed(
        Duration(seconds: 1),
      ); // Wait before restarting listening
      if (_inCall) _startListening();
    });
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message["role"] == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isUser ? Colors.deepPurple[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message["text"] ?? "",
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Capture'),
        backgroundColor: Colors.grey,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Tap Start to begin conversation'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _inCall ? Colors.red : Colors.white,
        label: Icon(_inCall ? Icons.call_end : Icons.call),
        // icon: Icon(_inCall ? Icons.call_end : Icons.call),
        onPressed: _inCall ? _endCall : _startCall,
      ),
    );
  }
}
