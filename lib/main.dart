import 'dart0:async';
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
    final savedKey = prefs.getString('groq_api_key');
    if (savedKey != null && savedKey.isNotEmpty) {
      _navigateToMain(savedKey);
    }
  }

  void _saveAndProceed() async {
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('groq_api_key', key);
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
                'BUJJI AI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Enter Groq API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAndProceed,
                child: const Text('Save & Start'),
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
    // స్పీడ్ తగ్గించి సాధారణ సంభాషణ వేగానికి పెట్టాం
    await _flutterTts.setSpeechRate(0.45);
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
          setState(() {
            _isListening = false;
          });
          if (_isSleepMode) {
            _startWakeWordListening();
          }
        }
      },
      onError: (errorNotification) {
        if (_isSleepMode) {
          _startWakeWordListening();
        }
      },
    );
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(seconds: 30), () {
      _enterSleepMode();
    });
  }

  void _enterSleepMode() {
    _flutterTts.stop();
    _speech.stop();
    setState(() {
      _isSleepMode = true;
      _statusText = "పడుకున్నా బాలా... ('Hi Bujji' అను)";
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
    _speak("హలో బాలా! లేచేశాను, చెప్పు ఏమిటి విశేషాలు?");
  }

  void _startWakeWordListening() {
    if (_isSleepMode && !_speech.isListening) {
      _speech.listen(
        onResult: (result) {
          String text = result.recognizedWords.toLowerCase();
          if (text.contains("bujji") || text.contains("బుజ్జి") || text.contains("hi")) {
            _wakeUp();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      );
    }
  }

  void _startListening() async {
    if (_isSleepMode) return;
    _resetSleepTimer();

    if (!_speech.isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              setState(() => _isListening = false);
              _processUserQuery(result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _processUserQuery(String userText) async {
    if (userText.trim().isEmpty) return;

    _resetSleepTimer();
    setState(() {
      _messages.add({"role": "user", "content": userText});
      _statusText = "ఆలోచిస్తున్నా బాలా...";
    });

    String responseText = await _getGroqResponse(userText);

    setState(() {
      _messages.add({"role": "assistant", "content": responseText});
      _statusText = responseText;
    });

    _speak(responseText);
  }

  Future<String> _getGroqResponse(String userText) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${widget.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": "You are Bujji, a funny, witty, Telugu speaking AI robot friend created by Bala. Speak naturally in simple conversational Telugu script with humor."
            },
            ..._messages
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        return "అయ్యో బాలా! చిన్న సమస్య వచ్చింది.";
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
            const Text(
              'BUJJI AI',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: () {
                  if (_isSleepMode) {
                    _wakeUp();
                  } else {
                    _startListening();
                  }
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _isSleepMode ? Colors.grey : Colors.cyanAccent, width: 4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: _isSleepMode ? 4 : 12, backgroundColor: Colors.cyanAccent),
                      const SizedBox(width: 40),
                      CircleAvatar(radius: _isSleepMode ? 4 : 12, backgroundColor: Colors.cyanAccent),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                if (_isSleepMode) {
                  _wakeUp();
                } else {
                  _enterSleepMode();
                }
              },
              icon: Icon(_isSleepMode ? Icons.wb_sunny : Icons.nightlight_round),
              label: Text(_isSleepMode ? "WAKE UP" : "SLEEP"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
