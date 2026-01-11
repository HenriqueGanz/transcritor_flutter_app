import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  String _selectedLocale = 'pt_BR';
  final Map<String, String> _availableLocales = {
    'pt_BR': '🇧🇷 Português (Brasil)',
    'en_US': '🇺🇸 English (USA)',
    'es_ES': '🇪🇸 Español (España)',
    'fr_FR': '🇫🇷 Français (France)',
    'de_DE': '🇩🇪 Deutsch (Deutschland)',
    'it_IT': '🇮🇹 Italiano (Italia)',
  };
  
  double _fontSize = 18.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 32.0;
  
  bool _isDarkMode = false;
  
  List<Map<String, String>> _transcriptionHistory = []; 

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initializeSpeech();
  }
  
  // Carregar preferências salvas
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLocale = prefs.getString('locale') ?? 'pt_BR';
      _fontSize = prefs.getDouble('fontSize') ?? 18.0;
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      
      // Carregar histórico
      final history = prefs.getStringList('history') ?? [];
      _transcriptionHistory = history.map((item) {
        final parts = item.split('|');
        return {
          'timestamp': parts[0],
          'text': parts.length > 1 ? parts[1] : '',
        };
      }).toList();
    });
  }
  
  // Salvar preferências
  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
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
    final theme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transcritor'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() => _isDarkMode = !_isDarkMode);
                _savePreference('darkMode', _isDarkMode);
              },
              tooltip: _isDarkMode ? 'Modo Claro' : 'Modo Escuro',
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showHistoryDialog,
              tooltip: 'Histórico',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildLanguageSelector(),
              const SizedBox(height: 12),
              
              _buildFontSizeControls(),
              const SizedBox(height: 12),
              
              // Área de Transcrição
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8.0),
                    color: _isDarkMode ? Colors.grey[900] : Colors.white,
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: _fontSize,
                            color: _isDarkMode ? Colors.white : Colors.black,
                          ),
                          children: [
                            TextSpan(text: _finalText),
                            TextSpan(
                              text: _currentText,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        textAlign: (_finalText.isEmpty && _currentText.isEmpty)
                            ? TextAlign.center
                            : TextAlign.start,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Botão Principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic),
                  label: Text(_isListening ? 'Parar Gravação' : 'Começar a Ouvir'),
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
              
              // Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar', style: TextStyle(fontSize: 12)),
                      onPressed: (_finalText.isNotEmpty || _currentText.isNotEmpty)
                          ? _copyToClipboard
                          : null,
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                      onPressed: (_finalText.isNotEmpty || _currentText.isNotEmpty)
                          ? _clearText
                          : null,
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Salvar', style: TextStyle(fontSize: 12)),
                      onPressed: (_finalText.isNotEmpty || _currentText.isNotEmpty)
                          ? _saveToFile
                          : null,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
  
  // Seletor de Idioma
  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.deepPurple),
          const SizedBox(width: 8),
          const Text('Idioma:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocale,
                isExpanded: true,
                items: _availableLocales.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: _isListening
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedLocale = value);
                          _savePreference('locale', value);
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  //Controles de Tamanho da Fonte
  Widget _buildFontSizeControls() {
    return Row(
      children: [
        const Icon(Icons.format_size, color: Colors.deepPurple),
        const SizedBox(width: 8),
        const Text('Tamanho:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _fontSize > _minFontSize
              ? () {
                  setState(() => _fontSize = (_fontSize - 2).clamp(_minFontSize, _maxFontSize));
                  _savePreference('fontSize', _fontSize);
                }
              : null,
          tooltip: 'Diminuir fonte',
        ),
        Text('${_fontSize.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _fontSize < _maxFontSize
              ? () {
                  setState(() => _fontSize = (_fontSize + 2).clamp(_minFontSize, _maxFontSize));
                  _savePreference('fontSize', _fontSize);
                }
              : null,
          tooltip: 'Aumentar fonte',
        ),
      ],
    );
  }
  
  void _toggleListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      _currentText = '';
      
      setState(() => _isListening = true);

      _speech.listen(
        localeId: _selectedLocale,
        onResult: (result) {
          if (mounted && _isListening) {
            setState(() => _currentText = result.recognizedWords);
          }
        },
        pauseFor: const Duration(seconds: 10),
      );
    }
  }
  
  void _copyToClipboard() async {
    final String textToCopy = (_finalText + ' ' + _currentText).trim();
    if (textToCopy.isEmpty) return;
    
    await Clipboard.setData(ClipboardData(text: textToCopy));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Texto copiado para área de transferência'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearText() async {
    final String textToSave = (_finalText + ' ' + _currentText).trim();
    
    if (textToSave.isNotEmpty) {
      await _saveToHistory(textToSave);
    }
    
    setState(() {
      _finalText = '';
      _currentText = '';
    });
  }

  void _saveToFile() async {
    final String textToSave = (_finalText + ' ' + _currentText).trim();
    if (textToSave.isEmpty) return;
    
    await _saveToHistory(textToSave);
    
    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/transcricao-${DateTime.now().millisecondsSinceEpoch}.txt';

    final file = File(filePath);
    await file.writeAsString(textToSave);

    final xfile = XFile(filePath);
    await Share.shareXFiles([xfile], text: 'Minha Transcrição');
  }
  
  Future<void> _saveToHistory(String text) async {
    final timestamp = DateTime.now().toIso8601String();
    
    _transcriptionHistory.insert(0, {
      'timestamp': timestamp,
      'text': text,
    });
    
    if (_transcriptionHistory.length > 20) {
      _transcriptionHistory = _transcriptionHistory.sublist(0, 20);
    }
    
    final prefs = await SharedPreferences.getInstance();
    final historyStrings = _transcriptionHistory
        .map((item) => '${item['timestamp']}|${item['text']}')
        .toList();
    await prefs.setStringList('history', historyStrings);
    
    setState(() {});
  }
  
  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.history, color: Colors.deepPurple),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Histórico',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _transcriptionHistory.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhuma transcrição salva ainda',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _transcriptionHistory.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = _transcriptionHistory[index];
                    final date = DateTime.parse(item['timestamp']!);
                    final formattedDate =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    
                    return ListTile(
                      dense: true,
                      title: Text(
                        item['text']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item['text']!));
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Texto copiado'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: 'Copiar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () async {
                              setState(() {
                                _transcriptionHistory.removeAt(index);
                              });
                              final prefs = await SharedPreferences.getInstance();
                              final historyStrings = _transcriptionHistory
                                  .map((item) => '${item['timestamp']}|${item['text']}')
                                  .toList();
                              await prefs.setStringList('history', historyStrings);
                              Navigator.pop(context);
                            },
                            tooltip: 'Excluir',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (_transcriptionHistory.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Limpar Tudo', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmar'),
                    content: const Text('Deseja realmente limpar todo o histórico?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  setState(() => _transcriptionHistory.clear());
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('history');
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}