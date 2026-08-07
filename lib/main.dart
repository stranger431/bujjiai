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
      home: const ApiKeyCheckScreen(),
    );
  }
}

// 1. API Key Check Screen
class ApiKeyCheckScreen extends StatefulWidget {
  const ApiKeyCheckScreen({super.key});

  @override
  State<ApiKeyCheckScreen> createState() => _ApiKeyCheckScreenState();
}

class _ApiKeyCheckScreenState extends State<ApiKeyCheckScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  final String _defaultPrompt =
      "Your name is Bujji. You are a witty, mischievous, very smart, and loving AI robot friend created by Bala. Speak in natural Telugu script. Be friendly and playful. Keep short answers for normal chat, but explain well if Bala asks for stories or long topics.";

  @override
  void initState() {
    super.initState();
    _checkSavedSettings();
  }

  Future<void> _checkSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('groq_api_key');
    final savedPrompt = prefs.getString('bujji_system_prompt') ?? _defaultPrompt;

    if (savedKey != null && savedKey.isNotEmpty) {
      _navigateToHome(savedKey, savedPrompt);
    } else {
      _promptController.text = savedPrompt;
    }
  }

  void _saveAndProceed() async {
    final key = _apiKeyController.text.trim();
    final prompt = _promptController.text.trim().isNotEmpty
        ? _promptController.text.trim()
        : _defaultPrompt;

    if (key.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('groq_api_key', key);
      await prefs.setString('bujji_system_prompt', prompt);
      _navigateToHome(key, prompt);
    }
  }

  void _navigateToHome(String key, String prompt) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BujjiHomeScreen(apiKey: key, systemPrompt: prompt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BUJJI SETUP'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                'BUJJI AI ROBOT',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Enter Groq API Key',
                  border: OutlineInputBorder(),
                  hintText: 'gsk_...',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _promptController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bujji Personality / System Prompt',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('START BUJJI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. Settings Screen
class SettingsScreen extends StatefulWidget {
  final String currentKey;
  final String currentPrompt;

  const SettingsScreen({super.key, required this.currentKey, required this.currentPrompt});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _keyController;
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.currentKey);
    _promptController = TextEditingController(text: widget.currentPrompt);
  }

  void _updateSettings() async {
    final newKey = _keyController.text.trim();
    final newPrompt = _promptController.text.trim();

    if (newKey.isNotEmpty && newPrompt.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('groq_api_key', newKey);
      await prefs.setString('bujji_system_prompt', newPrompt);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => BujjiHomeScreen(apiKey: newKey, systemPrompt: newPrompt),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bujji Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Groq API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _promptController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Bujji Personality Prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updateSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('SAVE & UPDATE BUJJI'),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Main Bujji Home Screen
class BujjiHomeScreen extends StatefulWidget {
  final String apiKey;
  final String systemPrompt;

  const BujjiHomeScreen({super.key, required this.apiKey, required this.systemPrompt});

  @override
  State<BujjiHomeScreen> createState() => _BujjiHomeScreenState();
}

class _BujjiHomeScreenState extends State<BujjiHomeScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  bool _isListening = false;
  bool _isSpeaking = false;
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
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.1);

    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
      _sleepTimer?.cancel();
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      _resetSleepTimer();
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
          if (_isSleepMode) {
            _startWakeWordListening();
          }
        }
      },
      onError: (error) {
        if (_isSleepMode) {
          _startWakeWordListening();
        }
      },
    );
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    if (_isSpeaking) return;

    _sleepTimer = Timer(const Duration(seconds: 30), () {
      if (!_isSpeaking) {
        _enterSleepMode();
      }
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
    if (_isSleepMode && !_speech.isListening && !_isSpeaking) {
      _speech.listen(
        onResult: (result) {
          String text = result.recognizedWords.toLowerCase();
          if (text.contains("bujji") ||
              text.contains("బుజ్జి") ||
              text.contains("hi") ||
              text.contains("oy")) {
            _wakeUp();
          }
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    }
  }

  void _startListening() async {
    if (_isSleepMode || _isSpeaking) return;
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
            {"role": "system", "content": widget.systemPrompt},
            ..._messages
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        return "అయ్యో బాలా! చిన్న సమస్య వచ్చింది, కీ సరిచూడు.";
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('BUJJI AI', style: TextStyle(color: Colors.cyanAccent)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.cyanAccent),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    currentKey: widget.apiKey,
                    currentPrompt: widget.systemPrompt,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                    border: Border.all(
                        color: _isSleepMode ? Colors.grey : Colors.cyanAccent, width: 4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                          radius: _isSleepMode ? 4 : 12, backgroundColor: Colors.cyanAccent),
                      const SizedBox(width: 40),
                      CircleAvatar(
                          radius: _isSleepMode ? 4 : 12, backgroundColor: Colors.cyanAccent),
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
