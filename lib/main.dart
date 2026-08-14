import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BujjiApp());
}

class BujjiApp extends StatelessWidget {
  const BujjiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bujji AI Robot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ApiKeyScreen(),
    );
  }
}

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSavedApiKey();
  }

  Future<void> _checkSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('sarvam_api_key');
    if (savedKey != null && savedKey.isNotEmpty) {
      _navigateToMain(savedKey);
    }
  }

  void _saveAndProceed() async {
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sarvam_api_key', key);
      _navigateToMain(key);
    }
  }

  void _navigateToMain(String key) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => BujjiHomeScreen(apiKey: key)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'BUJJI AI - SARVAM',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Enter Sarvam API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAndProceed,
                child: const Text('Save & Start Bujji'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BujjiHomeScreen extends StatefulWidget {
  final String apiKey;
  const BujjiHomeScreen({super.key, required this.apiKey});

  @override
  State<BujjiHomeScreen> createState() => _BujjiHomeScreenState();
}

class _BujjiHomeScreenState extends State<BujjiHomeScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  bool _isListening = false;
  bool _isSleepMode = false;
  String _statusText = "లేచేశా బాలా!";
  Timer? _sleepTimer;

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _initSpeech();
    _resetSleepTimer();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("te-IN");
    await _flutterTts.setSpeechRate(0.50); // స్పీడ్ కొంచెం పెంచాను
    await _flutterTts.setPitch(1.1);

    _flutterTts.setCompletionHandler(() {
      if (!_isSleepMode) {
        _startListening();
      }
    });
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          setState(() => _isListening = false);
          if (_isSleepMode) _startWakeWordListening();
        }
      },
    );
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(seconds: 40), () => _enterSleepMode());
  }

  void _enterSleepMode() {
    _flutterTts.stop();
    _speech.stop();
    setState(() {
      _isSleepMode = true;
      _statusText = "పడుకున్నా బాలా... ('Bujji' అని పిలు)";
    });
    _startWakeWordListening();
  }

  void _wakeUp() {
    _speech.stop();
    setState(() {
      _isSleepMode = false;
      _statusText = "లేచేశా బాలా!";
    });
    _resetSleepTimer();
    _speak("హలో బాలా! వచ్చేశాను.. చెప్పు ఏం విశేషం?");
  }

  void _startWakeWordListening() {
    if (_isSleepMode && !_speech.isListening) {
      _speech.listen(
        onResult: (result) {
          String text = result.recognizedWords.toLowerCase();
          if (text.contains("bujji") || text.contains("బుజ్జి")) {
            _wakeUp();
          }
        },
        listenFor: const Duration(seconds: 30),
        localeId: "te-IN",
      );
    }
  }

  void _startListening() async {
    if (_isSleepMode) return;
    _resetSleepTimer();

    bool available = await _speech.initialize();
    if (available && !_speech.isListening) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            setState(() => _isListening = false);
            _processUserQuery(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 10),
        localeId: "te-IN",
      );
    }
  }

  Future<void> _processUserQuery(String userText) async {
    if (userText.trim().isEmpty) return;

    _resetSleepTimer();
    setState(() {
      _messages.add({"role": "user", "content": userText});
      _statusText = "ఆలోచిస్తున్నా బాలా...";
    });

    String responseText = await _getSarvamResponse(userText);

    setState(() {
      _messages.add({"role": "assistant", "content": responseText});
      _statusText = responseText;
    });

    _speak(responseText);
  }

  Future<String> _getSarvamResponse(String userText) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.sarvam.ai/chat/completions'),
        headers: {
          'api-subscription-key': widget.apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "sarvam-1",
          "messages": [
            {
              "role": "system",
              "content": "నీ పేరు బుజ్జి. నువ్వు బాలా సృష్టించిన తెలివైన, అల్లరి చేసే చిన్నమ్మాయివి. చాలా సహజంగా, అచ్చతెలుగులో మాట్లాడు. సంభాషణ చాలా ముద్దుగా ఉండాలి."
            },
            ..._messages
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        return "అయ్యో బాలా! Sarvam AI కనెక్షన్ లో ఏదో తేడా ఉంది.";
      }
    } catch (e) {
      return "నెట్‌వర్క్ చెక్ చేసుకో బాలా!";
    }
  }

  void _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('BUJJI AI', style: TextStyle(fontSize: 22, color: Colors.white70)),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: () => _isSleepMode ? _wakeUp() : _startListening(),
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _isSleepMode ? Colors.grey : Colors.cyanAccent, width: 4),
                  ),
                  child: Center(child: Text(_isSleepMode ? "😴" : "😊", style: const TextStyle(fontSize: 80))),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _isSleepMode ? _wakeUp() : _enterSleepMode(),
              child: Text(_isSleepMode ? "WAKE UP" : "SLEEP"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
