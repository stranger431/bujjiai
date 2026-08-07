import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
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
      title: 'Bujji AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0E15),
        primaryColor: Colors.cyanAccent,
      ),
      home: const BujjiHomeScreen(),
    );
  }
}

class BujjiHomeScreen extends StatefulWidget {
  const BujjiHomeScreen({super.key});

  @override
  State<BujjiHomeScreen> createState() => _BujjiHomeScreenState();
}

class _BujjiHomeScreenState extends State<BujjiHomeScreen> {
  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;

  String _groqApiKey = "";
  String _systemPrompt =
      "You are Bujji, a playful, extremely witty, mischievous, affectionate, and smart AI assistant created for Bala. Speak strictly in clear, fun, conversational Telugu. Keep responses short, highly expressive, and full of emotion.";

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isSleeping = false;
  bool _isLoading = false;

  String _userSpeechText = "";
  String _bujjiResponseText = "చెప్పు బాలా!";

  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
    _speech = stt.SpeechToText();
    _loadSettingsAndInit();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("te-IN");
    _flutterTts.setPitch(1.2);
    _flutterTts.setSpeechRate(0.5);

    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      _resetInactivityTimer();
    });
  }

  Future<void> _loadSettingsAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groqApiKey = prefs.getString('groq_api_key') ?? "";
      _systemPrompt = prefs.getString('system_prompt') ?? _systemPrompt;
    });

    if (_groqApiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSettingsDialog(isFirstTime: true);
      });
    } else {
      _speak("చెప్పు బాలా!");
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isSpeaking && !_isListening) {
        setState(() {
          _isSleeping = true;
          _bujjiResponseText =
              "బుజ్జి నిద్రపోతోంది... 'Hi Bujji' అని పిలు బాలా!";
        });
      }
    });
  }

  Future<void> _speak(String text) async {
    if (_isSleeping) return;
    setState(() => _bujjiResponseText = text);
    await _flutterTts.speak(text);
  }

  void _toggleListening() async {
    if (_isSleeping) {
      _wakeUpBujji();
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _resetInactivityTimer();
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            if (_userSpeechText.isNotEmpty) {
              _processUserInput(_userSpeechText);
            }
          }
        },
        onError: (errorNotification) {
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _userSpeechText = "";
        });
        _inactivityTimer?.cancel();
        _speech.listen(
          localeId: "te-IN",
          onResult: (result) {
            setState(() {
              _userSpeechText = result.recognizedWords;
            });
            _checkWakeWord(_userSpeechText);
          },
        );
      }
    }
  }

  void _checkWakeWord(String text) {
    String lower = text.toLowerCase();
    if (lower.contains("hi bujji") ||
        lower.contains("oy bujji") ||
        lower.contains("హాయ్ బుజ్జి") ||
        lower.contains("ఓయ్ బుజ్జి")) {
      if (_isSleeping) {
        _wakeUpBujji();
      }
    }
  }

  void _wakeUpBujji() {
    setState(() {
      _isSleeping = false;
    });
    _speak("లేచేశా బాలా! చెప్పు ఏంటి విశేషాలు?");
    _resetInactivityTimer();
  }

  Future<void> _processUserInput(String input) async {
    if (input.trim().isEmpty) return;

    if (_groqApiKey.isEmpty) {
      _showSettingsDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "system", "content": _systemPrompt},
            {"role": "user", "content": input}
          ],
          "temperature": 0.8,
          "max_tokens": 150
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = data['choices'][0]['message']['content'] ??
            "ఏదో తేడా వచ్చింది బాలా!";
        setState(() => _isLoading = false);
        _speak(reply);
      } else {
        setState(() => _isLoading = false);
        _speak("అయ్యో API కనెక్ట్ అవ్వలేదు బాలా, సెట్టింగ్స్ చూడొచ్చుగా!");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _speak("నెట్‌వర్క్ ప్రాబ్లమ్ ఉన్నట్టుంది బాలా!");
    }
  }

  void _showSettingsDialog({bool isFirstTime = false}) {
    TextEditingController apiController =
        TextEditingController(text: _groqApiKey);
    TextEditingController promptController =
        TextEditingController(text: _systemPrompt);

    showDialog(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: Text(
          isFirstTime ? "Bujji Setup" : "Bujji Settings",
          style: const TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: apiController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Groq API Key",
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: promptController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Persona Prompt (అల్లరి / బిహేవియర్)",
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('groq_api_key', apiController.text.trim());
              await prefs.setString(
                  'system_prompt', promptController.text.trim());

              setState(() {
                _groqApiKey = apiController.text.trim();
                _systemPrompt = promptController.text.trim();
              });

              Navigator.pop(context);
              if (isFirstTime) {
                _speak("హేయ్ బాలా! సెటప్ అయిపోయింది, ఇక రచ్చ చేద్దాం!");
              }
            },
            child:
                const Text("SAVE", style: TextStyle(color: Colors.cyanAccent)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("BUJJI AI",
            style: TextStyle(
                color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.cyanAccent),
            onPressed: () => _showSettingsDialog(),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cute Bujji Face Display
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isSleeping
                              ? Colors.grey.shade900
                              : (_isSpeaking
                                  ? Colors.cyan.shade900
                                  : Colors.blueGrey.shade900),
                          boxShadow: [
                            BoxShadow(
                              color: _isSleeping
                                  ? Colors.transparent
                                  : (_isSpeaking
                                      ? Colors.cyanAccent.withOpacity(0.6)
                                      : Colors.blue.withOpacity(0.3)),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                          border: Border.all(
                            color:
                                _isSleeping ? Colors.grey : Colors.cyanAccent,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Left Eye
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 30,
                                height:
                                    _isSleeping ? 4 : (_isSpeaking ? 45 : 30),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              const SizedBox(width: 40),
                              // Right Eye
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 30,
                                height:
                                    _isSleeping ? 4 : (_isSpeaking ? 45 : 30),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Bujji Response Box
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E202C),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            _isLoading
                                ? "ఆగు బాలా ఆలోచిస్తున్నా..."
                                : _bujjiResponseText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Wake / Sleep Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSleeping
                          ? Colors.orangeAccent
                          : Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      if (_isSleeping) {
                        _wakeUpBujji();
                      } else {
                        setState(() {
                          _isSleeping = true;
                          _bujjiResponseText = "బుజ్జి నిద్రపోతోంది...";
                        });
                      }
                    },
                    icon: Icon(
                        _isSleeping ? Icons.power_settings_new : Icons.bedtime),
                    label: Text(_isSleeping ? "WAKE BUJJI" : "SLEEP"),
                  ),

                  // Mic Button
                  FloatingActionButton.large(
                    backgroundColor:
                        _isListening ? Colors.redAccent : Colors.cyanAccent,
                    onPressed: _toggleListening,
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
