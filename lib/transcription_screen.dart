import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState  extends State<TranscriptionScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  String _finalText = '';
  String _currentText = '';
  bool _isInitialized = false; 

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  void _initializeSpeech() async {
    final isAvailable = await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() {
            _isListening = false;
            if (_currentText.isNotEmpty) {
              _finalText += _finalText.isEmpty ? _currentText : ' $_currentText';
              _currentText = '';
            }
          });
        }
      },
    );

    if (isAvailable && mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcritor de Voz'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Seletor de idioma REMOVIDO
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 18.0, color: Colors.black),
                        children: [
                          TextSpan(text: _finalText),
                          TextSpan(
                            text: _currentText,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      textAlign: (_finalText.isEmpty && _currentText.isEmpty) ? TextAlign.center : TextAlign.start,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic),
                label: Text(_isListening ? 'Parar Gravação' : 'Começar a Ouvir'),
                // O botão só fica ativo após a inicialização bem-sucedida.
                onPressed: _isInitialized ? _toggleListening : null, 
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isListening ? Colors.redAccent : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpar Texto'),
                  onPressed: (_finalText.isNotEmpty || _currentText.isNotEmpty) ? _clearText : null,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Compartilhar texto'),
                  onPressed: (_finalText.isNotEmpty || _currentText.isNotEmpty) ? _saveToFile : null,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
  
  void _toggleListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (_currentText.isNotEmpty) {
        _finalText += _finalText.isEmpty ? _currentText : ' $_currentText';
      }
      _currentText = '';
      
      setState(() => _isListening = true);

      _speech.listen(
        localeId: 'pt_BR',
        onResult: (result) {
          if (mounted) setState(() => _currentText = result.recognizedWords);
        },
        pauseFor: const Duration(seconds: 10),
      );
    }
  }

  void _clearText() {
    setState(() {
      _finalText = '';
      _currentText = '';
    });
  }

  void _saveToFile() async {
    final String textToSave = (_finalText + ' ' + _currentText).trim();
    if (textToSave.isEmpty) return;
    
    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/transcricao-${DateTime.now().millisecondsSinceEpoch}.txt';

    final file = File(filePath);
    await file.writeAsString(textToSave);

    final xfile = XFile(filePath);
    await Share.shareXFiles([xfile], text: 'Minha Transcrição');
  }
}