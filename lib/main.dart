import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

// 1. Setup Screen for Groq API Key & System Prompt
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

// 3. Main Bujji Home Screen (Gemini Live Style Response & Controls)
class BujjiHomeScreen extends StatefulWidget {
  final String apiKey;
  final String systemPrompt;

  const BujjiHomeScreen({super.key, required this.apiKey, required this.systemPrompt});

  @override
  State<BujjiHomeScreen> createState() => _BujjiHomeScreenState();
}

class _BujjiHomeScreenState extends State<BujjiHomeScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _userStoppedManual = false;
  String _statusText = "చెప్పు బాలా, వింటున్నా!";

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeechOnce();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("te-IN");
    await _flutterTts.setSpeechRate(0.52); // వాయిస్ స్పీడ్ పెంచాను బాలా
    await _flutterTts.setPitch(1.1);

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = true);
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
      // మాట్లాడటం పూర్తవగానే ఆటోమేటిక్‌గా వినడం మొదలుపెడుతుంది
      if (!_userStoppedManual) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isSpeaking && !_isListening) {
            _startListening();
          }
        });
      }
    });
  }

  Future<void> _initSpeechOnce() async {
    _isSpeechInitialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (_isSpeechInitialized && mounted) {
      _startListening();
    }
  }

  // Smooth Listening Logic with Noise Filter
  void _startListening() async {
    if (_isSpeaking) {
      await _flutterTts.stop(); // నువ్వు మాట్లాడటానికి ట్రై చేస్తే Bujji మాట ఆగుతుంది
      setState(() => _isSpeaking = false);
    }

    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await _speech.initialize();
    }

    if (_isSpeechInitialized && !_speech.isListening) {
      setState(() {
        _isListening = true;
        _userStoppedManual = false;
        _statusText = "వింటున్నా బాలా...";
      });

      _speech.listen(
        onResult: (result) {
          // Gemini Live Interrupt: మాట్లాడేటప్పుడు ఏదైనా పదం వినబడితే టీటీఎస్ ని వెంటనే ఆపేస్తుంది
          if (_isSpeaking) {
            _flutterTts.stop();
            setState(() => _isSpeaking = false);
          }

          if (result.finalResult) {
            setState(() => _isListening = false);
            _processUserQuery(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3), // నిశ్శబ్దాన్ని త్వరగా గుర్తించి రెస్పాండ్ అవుతుంది
        localeId: "te_IN",
      );
    }
  }

  void _stopEverything() async {
    await _flutterTts.stop();
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _isSpeaking = false;
        _userStoppedManual = true;
        _statusText = "ఆగాను బాలా! మైక్ ఆన్ చేయడానికి సర్కిల్ నొక్కు.";
      });
    }
  }

  Future<void> _processUserQuery(String userText) async {
    if (userText.trim().isEmpty) {
      if (!_userStoppedManual) {
        _startListening();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _messages.add({"role": "user", "content": userText});
        _statusText = "ఆలోచిస్తున్నా బాలా...";
      });
    }

    String responseText = await _getGroqResponse(userText);

    if (mounted) {
      setState(() {
        _messages.add({"role": "assistant", "content": responseText});
        _statusText = responseText;
      });
    }

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
        return "అయ్యో బాలా! చిన్న సమస్య వచ్చింది, API కీ చెక్ చేయి.";
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
            // Interactive Face Circle
            Center(
              child: GestureDetector(
                onTap: () {
                  if (_isSpeaking) {
                    _flutterTts.stop();
                    _startListening();
                  } else if (_isListening) {
                    _stopEverything();
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
                      color: _isSpeaking
                          ? Colors.greenAccent
                          : (_isListening ? Colors.redAccent : Colors.cyanAccent),
                      width: 4,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: _isSpeaking
                            ? Colors.greenAccent
                            : (_isListening ? Colors.redAccent : Colors.cyanAccent),
                      ),
                      const SizedBox(width: 40),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: _isSpeaking
                            ? Colors.greenAccent
                            : (_isListening ? Colors.redAccent : Colors.cyanAccent),
                      ),
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
            // Stop / Listen Button
            ElevatedButton.icon(
              onPressed: () {
                if (_isListening || _isSpeaking) {
                  _stopEverything();
                } else {
                  _startListening();
                }
              },
              icon: Icon(_isListening || _isSpeaking ? Icons.stop : Icons.mic),
              label: Text(_isListening || _isSpeaking ? "PAUSE / STOP" : "START TALKING"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening || _isSpeaking ? Colors.redAccent : Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
