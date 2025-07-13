import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_text/pdf_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(TruthGuardApp());
}

class TruthGuardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruthGuard',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: TruthGuardHome(),
    );
  }
}

class TruthGuardHome extends StatefulWidget {
  @override
  _TruthGuardHomeState createState() => _TruthGuardHomeState();
}

class _TruthGuardHomeState extends State<TruthGuardHome> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _response = '';
  bool _isListening = false;
  bool _loading = false;

  final String apiKey = "sk-or-v1-YOUR_API_KEY"; // 👈 Replace this with your API key

  Future<void> detectFakeNews(String text) async {
    setState(() {
      _loading = true;
      _response = '';
    });

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "openrouter/auto", // 👈 Let OpenRouter choose the best one
          "messages": [
            {"role": "system", "content": "You are a fake news detection assistant."},
            {"role": "user", "content": "Check if the following content is fake news:\n$text"}
          ],
          "max_tokens": 1000 // ✅ Within free plan limits
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['choices'][0]['message']['content'];
        setState(() => _response = content.trim());
      } else {
        setState(() => _response = "❌ Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      setState(() => _response = "❌ Network error: $e");
    }

    setState(() => _loading = false);
  }

  Future<void> pickAndReadFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'txt']);

    if (result != null) {
      final path = result.files.single.path!;
      final ext = path.split('.').last;

      String content = '';

      if (ext == 'pdf') {
        final doc = await PDFDoc.fromPath(path);
        content = await doc.text;
      } else if (ext == 'txt') {
        content = await File(path).readAsString();
      }

      _controller.text = content;
    }
  }

  Future<void> startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (val) {
        setState(() {
          _controller.text = val.recognizedWords;
        });
      });
    }
  }

  void stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TruthGuard'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Enter or upload text',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: pickAndReadFile,
                  icon: Icon(Icons.upload_file),
                  label: Text('Upload'),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isListening ? stopListening : startListening,
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  label: Text(_isListening ? 'Stop' : 'Speak'),
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => detectFakeNews(_controller.text),
                  icon: Icon(Icons.search),
                  label: Text('Check'),
                ),
              ],
            ),
            SizedBox(height: 20),
            _loading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _response,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
