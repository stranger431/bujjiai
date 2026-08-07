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

// -------------------------------------------------------------
// 1. API Key తీసుకునే స్క్రీన్
// -------------------------------------------------------------
class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingKey();
  }

  void _checkExistingKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedKey = prefs.getString('groq_api_key');
    if (savedKey != null && savedKey.isNotEmpty) {
      // కీ ఇప్పటికే ఉంటే నేరుగా హోమ్ స్క్రీన్‌కి వెళ్ళిపోదాం
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BujjiHomeScreen(groqApiKey: savedKey)),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _saveKey() async {
    String key = _keyController.text.trim();
    if (key.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('groq_api_key', key);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BujjiHomeScreen(groqApiKey: key)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("దయచేసి సరైన Groq API Key ఇవ్వండి బాలా!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BUJJI - Setup Key'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "నీ Groq API Key ఇక్కడ ఎంటర్ చేయి బాలా!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                labelText: 'Groq API Key',
                hintText: 'gsk_... ఇచ్చేయి',
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveKey,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text('START BUJJI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. అసలైన బుజ్జి హోమ్ స్క్రీన్ (రోబోట్ ఫేస్ & వాయిస్)
// -------------------------------------------------------------
class BujjiHomeScreen extends StatefulWidget {
  final String groqApiKey;
  const BujjiHomeScreen({super.key, required this.groqApiKey});

  @override
  State<BujjiHomeScreen> createState() => _BujjiHomeScreenState();
}

class _BujjiHomeScreenState extends State<BujjiHomeScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isAwake = false;
  bool _isSpeaking = false;
  String _statusText = "బుజ్జి నిద్రపోతోంది... 'Hi Bujji' అని పిలు బాలా!";
  
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    _initSpeechAndTts();
  }

  void _initSpeechAndTts() async {
    await _tts.setLanguage("te-IN");
    await _tts.setPitch(1.2);
    await _tts.setSpeechRate(0.9);

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
      if (_isAwake) {
        _startListening();
      }
    });

    bool available = await _speech.initialize(
      onError: (val) => print('onError: $val'),
      onStatus: (val) {
        if (val == 'done' && _isAwake && !_isSpeaking) {
          _startListening();
        }
      },
    );

    if (available) {
      _startListening();
    }
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(seconds: 30), () {
      if (_isAwake) {
        _goToSleep();
      }
    });
  }

  void _wakeUp(String greeting) async {
    setState(() {
      _isAwake = true;
      _statusText = greeting;
    });
    _resetSleepTimer();
    await _speak(greeting);
  }

  void _goToSleep() async {
    _sleepTimer?.cancel();
    setState(() {
      _isAwake = false;
      _statusText = "బుజ్జి నిద్రపోతోంది... 'Hi Bujji' అని పిలు బాలా!";
    });
    await _speak("సరే బాలా, నేను చిన్న కునుకు తీస్తున్నా!");
  }

  void _startListening() async {
    if (!_speech.isListening && !_isSpeaking) {
      await _speech.listen(
        onResult: (val) {
          String text = val.recognizedWords.toLowerCase();
          if (text.isNotEmpty) {
            _handleUserSpeech(text);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _handleUserSpeech(String text) {
    _resetSleepTimer();

    if (!_isAwake) {
      if (text.contains("bujji") || text.contains("బుజ్జి") || text.contains("hi") || text.contains("oy")) {
        _wakeUp("లేచేశా బాలా! చెప్పు ఏంటి విశేషాలు?");
      }
      return;
    }

    _getGroqResponse(text);
  }

  Future<void> _getGroqResponse(String prompt) async {
    setState(() => _statusText = "ఆలోచిస్తున్నా బాలా...");
    
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${widget.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'Your name is Bujji. You are a witty, playful AI assistant speaking in Telugu with your creator Bala. Keep responses short and friendly.'
            },
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String reply = data['choices'][0]['message']['content'];
        setState(() => _statusText = reply);
        await _speak(reply);
      } else {
        setState(() => _statusText = "చిన్న ఎర్రర్ వచ్చింది బాలా, కీ సరిచూడు!");
      }
    } catch (e) {
      setState(() => _statusText = "నెట్‌వర్క్ చెక్ చేసుకో బాలా!");
    }
  }

  Future<void> _speak(String text) async {
    setState(() => _isSpeaking = true);
    await _speech.stop();
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BUJJI AI'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _isAwake ? Colors.cyanAccent : Colors.grey, width: 4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: _isAwake ? 35 : 30,
                    height: _isAwake ? 35 : 6,
                    decoration: BoxDecoration(
                      color: _isAwake ? Colors.cyanAccent : Colors.cyan,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Container(
                    width: _isAwake ? 35 : 30,
                    height: _isAwake ? 35 : 6,
                    decoration: BoxDecoration(
                      color: _isAwake ? Colors.cyanAccent : Colors.cyan,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _isAwake ? _goToSleep() : _wakeUp("లేచేశా బాలా!"),
                  icon: Icon(_isAwake ? Icons.bedtime : Icons.power_settings_new),
                  label: Text(_isAwake ? "SLEEP" : "WAKE BUJJI"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAwake ? Colors.grey : Colors.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
