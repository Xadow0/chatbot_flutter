import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/services/gemini_service.dart';
import 'package:markdown_widget/markdown_widget.dart';
// import '../../../data/repositories/conversation_repository.dart';

class Module2Page extends StatefulWidget {
  const Module2Page({super.key});

  @override
  State<Module2Page> createState() => _Module2PageState();
}

class _Module2PageState extends State<Module2Page> {
  int _currentPage = 0;

  void _nextPage() {
    setState(() {
      _currentPage++;
    });
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _completeModule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('module_2_completed', true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header con botón de retroceso
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: _previousPage,
                    tooltip: 'Volver',
                  ),
                ],
              ),
            ),
            // Contenido de la página actual
            Expanded(
              child: _buildCurrentPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _IntroPage(onStart: _nextPage);
      case 1:
        return _ComparisonPage(onNext: _nextPage);
      case 2:
        return _PromptBuilderPage(onComplete: _completeModule);
      default:
        return const SizedBox();
    }
  }
}

// ============= PÁGINA INICIAL =============
class _IntroPage extends StatelessWidget {
  final VoidCallback onStart;

  const _IntroPage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_note,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'El arte del prompting',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Aprende a comunicarte efectivamente con la IA',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }
}

// ============= PÁGINA DE COMPARACIÓN =============
class _ComparisonPage extends StatefulWidget {
  final VoidCallback onNext;

  const _ComparisonPage({required this.onNext});

  @override
  State<_ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<_ComparisonPage> {
  String _displayedExplanation = '';
  final String _fullExplanation =
      'Cada vez que hablas con una IA estás enviando un prompt. '
      'Un prompt es la instrucción, lo que le dices para que te ayude, pero, '
      'al igual que en la vida real, no todos los mensajes se entienden igual.';

  bool _showConversations = false;
  bool _conversation1Complete = false;
  bool _conversation2Complete = false;
  bool _showFinalText = false;
  String _displayedFinalText = '';
  final String _fullFinalText =
      'Un buen prompt es como una receta, incluye los ingredientes y las instrucciones para realizarla';

  // Conversación 1
  final String _prompt1 = 'Haz un texto bonito sobre IA';
  final String _response1 =
      'La inteligencia artificial es fascinante. Es tecnología moderna que ayuda en muchas tareas.';

  // Conversación 2
  final String _prompt2 =
      'Haz un texto breve, optimista, para una presentación motivacional, sobre aprender sobre IA';
  final String _response2 =
      '¡El futuro está en tus manos! Aprender sobre IA no es solo dominar una tecnología, '
      'es abrir la puerta a infinitas posibilidades. Cada concepto que comprendes te acerca a '
      'crear soluciones innovadoras que pueden cambiar el mundo. ¡Empieza hoy y sé parte de la revolución!';

  String _displayedPrompt1 = '';
  String _displayedResponse1 = '';
  String _displayedPrompt2 = '';
  String _displayedResponse2 = '';

  // Lista de timers activos para cancelarlos al destruir el widget
  final List<Timer> _activeTimers = [];

  @override
  void initState() {
    super.initState();
    _startExplanationAnimation();
  }

  @override
  void dispose() {
    // Cancelar todos los timers activos
    for (var timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
    super.dispose();
  }

  void _startExplanationAnimation() {
    int charIndex = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
          if (charIndex < _fullExplanation.length) {
        setState(() {
          _displayedExplanation = _fullExplanation.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        _activeTimers.remove(timer);
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _showConversations = true;
              });
              _startConversation1();
            }
          });
        }
      }
    });
    _activeTimers.add(timer);
  }

  void _startConversation1() {
    _animateText(_prompt1, (text) {
      setState(() {
        _displayedPrompt1 = text;
      });
    }, () {
      Future.delayed(const Duration(milliseconds: 500), () {
        _animateText(_response1, (text) {
          setState(() {
            _displayedResponse1 = text;
          });
        }, () {
          setState(() {
            _conversation1Complete = true;
          });
          _startConversation2();
        });
      });
    });
  }

  void _startConversation2() {
    _animateText(_prompt2, (text) {
      setState(() {
        _displayedPrompt2 = text;
      });
    }, () {
      Future.delayed(const Duration(milliseconds: 500), () {
        _animateText(_response2, (text) {
          setState(() {
            _displayedResponse2 = text;
          });
        }, () {
          setState(() {
            _conversation2Complete = true;
          });
          Future.delayed(const Duration(milliseconds: 800), () {
            setState(() {
              _showFinalText = true;
            });
            _startFinalTextAnimation();
          });
        });
      });
    });
  }

  void _animateText(String text, Function(String) onUpdate, VoidCallback onComplete) {
    int charIndex = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < text.length) {
        onUpdate(text.substring(0, charIndex + 1));
        charIndex++;
      } else {
        timer.cancel();
        _activeTimers.remove(timer);
        if (mounted) {
          onComplete();
        }
      }
    });
    _activeTimers.add(timer);
  }

  void _startFinalTextAnimation() {
    int charIndex = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < _fullFinalText.length) {
        setState(() {
          _displayedFinalText = _fullFinalText.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        _activeTimers.remove(timer);
      }
    });
    _activeTimers.add(timer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Explicación inicial
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _displayedExplanation,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
          ),

          if (_showConversations) ...[
            const SizedBox(height: 32),

            // Conversación 1
            _buildConversationBox(
              theme: theme,
              title: 'Conversación 1',
              userPrompt: _displayedPrompt1,
              aiResponse: _displayedResponse1,
              isComplete: _conversation1Complete,
            ),

            const SizedBox(height: 24),

            // Conversación 2
            _buildConversationBox(
              theme: theme,
              title: 'Conversación 2',
              userPrompt: _displayedPrompt2,
              aiResponse: _displayedResponse2,
              isComplete: _conversation2Complete,
            ),
          ],

          if (_showFinalText) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.2),
                    theme.colorScheme.secondary.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _displayedFinalText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Siguiente'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationBox({
    required ThemeData theme,
    required String title,
    required String userPrompt,
    required String aiResponse,
    required bool isComplete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Mensaje del usuario
          if (userPrompt.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  radius: 16,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userPrompt,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Mensaje de la IA
          if (aiResponse.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  radius: 16,
                  child: Icon(
                    Icons.smart_toy,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      aiResponse,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Indicador de carga
          if (userPrompt.isNotEmpty && aiResponse.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generando respuesta...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============= PÁGINA DE CONSTRUCCIÓN DE PROMPT =============
class _PromptBuilderPage extends StatefulWidget {
  final VoidCallback onComplete;

  const _PromptBuilderPage({required this.onComplete});

  @override
  State<_PromptBuilderPage> createState() => _PromptBuilderPageState();
}

class _PromptBuilderPageState extends State<_PromptBuilderPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();

  // Partes del prompt
  final Map<String, String> _promptParts = {
    'contexto': '',
    'rol': '',
    'tarea': '',
    'formato': '',
    'tono': '',
  };

  final List<String> _partOrder = ['contexto', 'rol', 'tarea', 'formato', 'tono'];
  final Map<String, String> _partLabels = {
    'contexto': 'Contexto',
    'rol': 'Rol',
    'tarea': 'Tarea',
    'formato': 'Formato',
    'tono': 'Tono',
  };

  final Map<String, String> _partDescriptions = {
    'contexto': '¿Cuál es el contexto o tema sobre el que quieres trabajar?',
    'rol': '¿Qué rol debe adoptar la IA? (profesor, experto, guía, etc.)',
    'tarea': '¿Qué tarea específica debe realizar?',
    'formato': '¿En qué formato deseas la respuesta? (lista, párrafo, tabla, etc.)',
    'tono': '¿Qué tono debe usar? (formal, informal, motivador, técnico, etc.)',
  };

  int _currentPartIndex = 0;
  final List<_ChatMessage> _messages = [];
  bool _waitingForInput = false;
  bool _promptComplete = false;
  // bool _showingFinalPrompt = false; // removed (unused)
  // Note: removed unused _generatingResponse to avoid analyzer warnings
  String _aiResponse = '';
  bool _responseAnimationComplete = false;
  // Indica que Gemini devolvió la respuesta y que se eliminó el mensaje "Generando respuesta"
  bool _geminiReturned = false;
    
  // Para guardar la conversación
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = 'modulo2_${DateTime.now().millisecondsSinceEpoch}';
    _startConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startConversation() {
    _addMessage(
      _ChatMessage(
        text: 'Para crear un prompt completo para una tarea compleja es conveniente que '
            'este cumpla los siguientes puntos. Piensa en un tema sobre el que quieras '
            'aprender o obtener un resultado completo y vamos a realizarlo!',
        isUser: false,
        isAnimated: true,
      ),
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      _askForNextPart();
    });
  }

  void _askForNextPart() {
    if (_currentPartIndex < _partOrder.length) {
      final partKey = _partOrder[_currentPartIndex];
      final description = _partDescriptions[partKey]!;

      _addMessage(
        _ChatMessage(
          text: '${_currentPartIndex + 1}. ${_partLabels[partKey]}\n$description',
          isUser: false,
          isAnimated: true,
        ),
      );

      setState(() {
        _waitingForInput = true;
      });
    } else {
      _showCompletePrompt();
    }
  }

  void _addMessage(_ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
    _saveConversation();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _addMessage(_ChatMessage(text: text, isUser: true, isAnimated: false));
    _messageController.clear();

    // Guardar la parte del prompt
    final partKey = _partOrder[_currentPartIndex];
    _promptParts[partKey] = text;

    setState(() {
      _waitingForInput = false;
      _currentPartIndex++;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _askForNextPart();
    });
  }

  void _showCompletePrompt() {
    setState(() {
      _promptComplete = true;
    });

    final completePrompt = _buildCompletePrompt();

    _addMessage(
      _ChatMessage(
        text: '¡Perfecto! Aquí está tu prompt completo:\n\n$completePrompt',
        isUser: false,
        isAnimated: true,
      ),
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      _addMessage(
        _ChatMessage(
          text: 'Generando respuesta...',
          isUser: false,
          isAnimated: true,
        ),
      );

      setState(() {
        _responseAnimationComplete = false;
      });

      // Llamar a Gemini en lugar de simular
      Future.delayed(const Duration(milliseconds: 1000), () {
        _getGeminiResponse();
      });
    });
  }

  String _buildCompletePrompt() {
    final parts = <String>[];
    _promptParts.forEach((key, value) {
      if (value.isNotEmpty) {
        parts.add('${_partLabels[key]}: $value');
      }
    });
    return parts.join('\n');
  }

  // _simulateAIResponse removed - we now call GeminiService directly

  Future<void> _getGeminiResponse() async {
    try {
      final completePrompt = _buildCompletePrompt();
      
      // Llamar a Gemini
      final response = await _geminiService.generateContent(completePrompt);
      
      if (!mounted) return;
      
      // Remover mensaje de "Generando..." y agregar mensaje AI con callback
      _messages.removeLast(); // Remover mensaje de "Generando..."
      // Marcamos que Gemini devolvió la respuesta y ya se borró el marcador "Generando respuesta"
      setState(() {
        _geminiReturned = true;
      });

      // Añadir la respuesta animada y pasar un onComplete para habilitar botones
      _addMessage(
        _ChatMessage(
          text: response,
          isUser: false,
          isAnimated: true,
          onComplete: () {
            if (!mounted) return;
            setState(() {
              _aiResponse = response;
              // Marcar que la animación finalizó
              _responseAnimationComplete = true;
            });
            // Guardar la conversación actualizada (ahora completada)
            _saveConversation();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        // on error, ensure response animation flag is false and gemini flag reset
        _responseAnimationComplete = false;
        _geminiReturned = false;
      });

  _messages.removeLast();

      _addMessage(
        _ChatMessage(
          text: 'Error al generar respuesta: $e\n\nPor favor, intenta de nuevo.',
          isUser: false,
          isAnimated: false,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _saveConversation() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final conversationsDir = Directory('${directory.path}/conversations/modulo2');
      
      if (!await conversationsDir.exists()) {
        await conversationsDir.create(recursive: true);
      }

      final file = File('${conversationsDir.path}/$_conversationId.json');
      
      final conversationData = {
        'id': _conversationId,
        'module': 'modulo2',
        'timestamp': DateTime.now().toIso8601String(),
        'messages': _messages.map((msg) => {
          'text': msg.text,
          'isUser': msg.isUser,
        }).toList(),
        'promptParts': _promptParts,
        'completed': _aiResponse.isNotEmpty,
      };

      await file.writeAsString(jsonEncode(conversationData));
    } catch (e) {
      print('Error al guardar conversación: $e');
    }
  }

  void _restart() {
    setState(() {
      _messages.clear();
      _promptParts.forEach((key, _) => _promptParts[key] = '');
      _currentPartIndex = 0;
      _waitingForInput = false;
      _promptComplete = false;
  _aiResponse = '';
  _geminiReturned = false;
      _responseAnimationComplete = false;
      _conversationId = 'modulo2_${DateTime.now().millisecondsSinceEpoch}';
    });
    _startConversation();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Estructura de un buen prompt',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // Lista de mensajes
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageBubble(theme, message);
            },
          ),
        ),

  // Botones finales: mostrar cuando el prompt esté completo y la animación de la respuesta haya terminado
  if (_promptComplete && _responseAnimationComplete)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _restart,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                    child: const Text('Volver a empezar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onComplete,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Finalizar'),
                  ),
                ),
              ],
            ),
          ),

        // Input de mensaje
        if (_waitingForInput && !_promptComplete)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu respuesta...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(
                    Icons.send,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        // Área de finalización: cuando ya no estamos pidiendo partes y el prompt está completo,
        // mostramos un único botón 'Finaliza' en la zona de input.
        if (!_waitingForInput && _promptComplete)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _geminiReturned ? widget.onComplete : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Finaliza'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(ThemeData theme, _ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              radius: 16,
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildMessageContent(theme, message),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              radius: 16,
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],

          
        ],
      ),
    );
  }

  // Decide how to render the message content: animated plain text, selectable plain text,
  // or a Markdown widget if the text looks like markdown/code.
  Widget _buildMessageContent(ThemeData theme, _ChatMessage message) {
    final text = message.text;

    // Simple heuristic to detect markdown/code formatting from Gemini
    bool looksLikeMarkdown(String t) {
      if (t.contains('```')) return true;
      if (t.contains('\n- ') || t.contains('\n* ') || t.contains('\n1. ')) return true;
      if (RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(t)) return true;
      if (t.contains('**') || t.contains('__') || t.contains('`')) return true;
      return false;
    }

    String cleanMarkdownText(String t) {
      String cleaned = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      cleaned = cleaned.trim();
      return cleaned;
    }

    // If the message is from the AI and it looks like markdown, render with MarkdownWidget
    if (!message.isUser && looksLikeMarkdown(text)) {
      return MarkdownWidget(
        data: cleanMarkdownText(text),
        shrinkWrap: true,
        selectable: true,
        config: MarkdownConfig(
          configs: [
            PConfig(
              textStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            H1Config(
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            H2Config(
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            H3Config(
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            CodeConfig(
              style: TextStyle(
                backgroundColor: theme.colorScheme.surfaceContainer,
                color: theme.colorScheme.primary,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            PreConfig(
              textStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
            ),
            ListConfig(
              marker: (bool isOrdered, int depth, int index) {
                if (isOrdered) {
                  return Text(
                    '${index + 1}. ',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  );
                }
                return Text(
                  '• ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Otherwise, keep the previous behavior: animate if requested, else plain selectable text
    if (message.isAnimated) {
      return _AnimatedText(text: text, onComplete: message.onComplete);
    }

    return SelectableText(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        height: 1.5,
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isAnimated;
  final VoidCallback? onComplete;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isAnimated = false,
    this.onComplete,
  });
}

class _AnimatedText extends StatefulWidget {
  final String text;
  final VoidCallback? onComplete;

  const _AnimatedText({required this.text, this.onComplete});

  @override
  State<_AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<_AnimatedText> {
  String _displayedText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animateText();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _animateText() {
    int charIndex = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < widget.text.length) {
        setState(() {
          _displayedText = widget.text.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        // animation finished
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      _displayedText,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.5,
      ),
    );
  }
}