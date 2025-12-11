import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/gemini_service.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../../../../domain/entities/message_entity.dart';
import '../../../../domain/repositories/iconversation_repository.dart';
import 'package:provider/provider.dart';

class Module2Page extends StatefulWidget {
  const Module2Page({super.key});

  @override
  State<Module2Page> createState() => _Module2PageState();
}

class _Module2PageState extends State<Module2Page> {
  int _currentPage = 0;
  late final IConversationRepository _conversationRepository;

  @override
  void initState() {
    super.initState();
    _conversationRepository = Provider.of<IConversationRepository>(context, listen: false);
  }

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

  void _goHome() {
    Navigator.pop(context);
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: _previousPage,
                    tooltip: 'Volver',
                  ),
                  IconButton(
                    icon: const Icon(Icons.home_rounded, size: 28),
                    onPressed: _goHome,
                    tooltip: 'Salir al menú',
                  ),
                ],
              ),
            ),
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
        return _PromptBuilderPage(
          onComplete: _completeModule,
          conversationRepository: _conversationRepository,
        );
      default:
        return const SizedBox();
    }
  }
}

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
          Icon(Icons.edit_note, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 32),
          Text(
            'El arte del prompting',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Aprende a comunicarte efectivamente con la IA',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }
}

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
  bool _allAnimationsComplete = false;

  String _displayedFinalText = '';
  final String _fullFinalText =
      'Un buen prompt es como una receta, incluye los ingredientes y las instrucciones para realizarla';

  final String _prompt1 = 'Haz un frase bonita sobre IA';
  final String _response1 =
      'La inteligencia artificial es fascinante. Es una tecnología moderna que ayuda en muchas tareas.';

  final String _prompt2 =
      'Haz un texto breve, optimista, para una presentación motivacional, sobre aprender acerca de IA Generativa';
  final String _response2 =
      'Aprender sobre IA Generativa no es solo dominar una tecnología, '
      'es abrir la puerta a infinitas posibilidades. Cada concepto que comprendes te acerca a '
      'crear soluciones innovadoras que pueden cambiar el mundo. ¡Empieza hoy y sé parte de la revolución!';

  String _displayedPrompt1 = '';
  String _displayedResponse1 = '';
  String _displayedPrompt2 = '';
  String _displayedResponse2 = '';

  final List<Timer> _activeTimers = [];

  @override
  void initState() {
    super.initState();
    _startExplanationAnimation();
  }

  @override
  void dispose() {
    for (var timer in _activeTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _skipAnimations() {
    for (var timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();

    if (mounted) {
      setState(() {
        _displayedExplanation = _fullExplanation;
        _showConversations = true;
        _displayedPrompt1 = _prompt1;
        _displayedResponse1 = _response1;
        _conversation1Complete = true;
        _displayedPrompt2 = _prompt2;
        _displayedResponse2 = _response2;
        _conversation2Complete = true;
        _showFinalText = true;
        _displayedFinalText = _fullFinalText;
        _allAnimationsComplete = true;
      });
    }
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
        if (mounted) onComplete();
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
        setState(() {
          _allAnimationsComplete = true;
        });
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
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _displayedExplanation,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
              if (!_allAnimationsComplete)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextButton.icon(
                    onPressed: _skipAnimations,
                    icon: const Icon(Icons.fast_forward, size: 16),
                    label: const Text('Saltar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
          if (_showConversations) ...[
            const SizedBox(height: 32),
            _buildConversationBox(
                theme: theme,
                title: 'Conversación 1',
                userPrompt: _displayedPrompt1,
                aiResponse: _displayedResponse1,
                isComplete: _conversation1Complete),
            const SizedBox(height: 24),
            _buildConversationBox(
                theme: theme,
                title: 'Conversación 2',
                userPrompt: _displayedPrompt2,
                aiResponse: _displayedResponse2,
                isComplete: _conversation2Complete),
          ],
          if (_showFinalText) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withAlpha((0.2 * 255).round()),
                    theme.colorScheme.secondary.withAlpha((0.2 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: theme.colorScheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _displayedFinalText,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_allAnimationsComplete) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Siguiente'),
            ),
          ] else if (_showFinalText) ...[
            const SizedBox(height: 82),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationBox(
      {required ThemeData theme,
      required String title,
      required String userPrompt,
      required String aiResponse,
      required bool isComplete}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withAlpha((0.3 * 255).round()), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          if (userPrompt.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    radius: 16,
                    child: Icon(Icons.person, size: 18, color: theme.colorScheme.onPrimaryContainer)),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration:
                            BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text(userPrompt, style: theme.textTheme.bodyMedium))),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (aiResponse.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    radius: 16,
                    child: Icon(Icons.smart_toy, size: 18, color: theme.colorScheme.onSecondaryContainer)),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text(aiResponse, style: theme.textTheme.bodyMedium))),
              ],
            ),
          ],
          if (userPrompt.isNotEmpty && aiResponse.isEmpty)
            Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Row(children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                  const SizedBox(width: 8),
                  Text('Generando respuesta...',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round())))
                ]))
        ],
      ),
    );
  }
}

class _PromptBuilderPage extends StatefulWidget {
  final VoidCallback onComplete;
  final IConversationRepository conversationRepository;

  const _PromptBuilderPage({
    required this.onComplete,
    required this.conversationRepository,
  });

  @override
  State<_PromptBuilderPage> createState() => _PromptBuilderPageState();
}

class _PromptBuilderPageState extends State<_PromptBuilderPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final GeminiService _geminiService = GeminiService();

  final StreamController<void> _skipSignal = StreamController<void>.broadcast();

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
    'contexto': 'Escribe el contexto o tema sobre el que estas trabajando. Por ejemplo: '
        '"Estoy preparando una presentación sobre IA Generativa para un público no técnico."',
    'rol': 'Indica que rol debe adoptar la IA (profesor, experto, guía, etc.). Por ejemplo: '
        '"Actúa como un experto en IA Generativa con experiencia en educación."',
    'tarea': 'Indica la tarea específica que deseas realizar. Por ejemplo: '
        '"Crea un esquema para una presentación de 10 minutos sobre los conceptos básicos de IA Generativa."',
    'formato': 'Ahora indica en que forma to quieres que te sea dada la respuesta (lista, párrafo, tabla, etc.). Por ejemplo: '
        '"Proporciona la información en formato de lista de diapositivas con su correspondiente información y guión"',
    'tono': 'Indica el tono más adecuado para la tarea que necesitas (formal, informal, motivador, técnico, etc.). Por ejemplo: '
        '"Utiliza un tono motivador y accesible para una audiencia general."',
  };

  int _currentPartIndex = 0;
  bool _waitingForInput = false;
  bool _promptComplete = false;
  bool _responseAnimationComplete = false;
  bool _geminiReturned = false;
  String? _conversationId;

  Timer? _introTimer;
  bool _isTyping = false;
  StreamSubscription<String>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _conversationId = 'modulo2_${DateTime.now().millisecondsSinceEpoch}';
    _startConversation();
  }

  @override
  void dispose() {
    _saveConversation();
    _messageController.dispose();
    _scrollController.dispose();
    _introTimer?.cancel();
    _skipSignal.close();
    _streamSubscription?.cancel();
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

    _introTimer = Timer(const Duration(milliseconds: 2000), () {
      _askForNextPart();
    });
  }

  void _skipCurrentAnimation() {
    _introTimer?.cancel();

    _skipSignal.add(null);

    if (_currentPartIndex == 0 && !_waitingForInput) {
      _askForNextPart();
    }
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
      if (message.isAnimated) {
        _isTyping = true;
      }
    });
    _scrollToBottom();
  }

  void _handleMessageComplete() {
    if (mounted) {
      setState(() {
        _isTyping = false;
      });
    }
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

  Future<void> _getGeminiResponse() async {
    try {
      final userPrompt = _buildCompletePrompt();

      final evaluationPrompt = '''
Actúa como una experta Mentora en Ingeniería de Prompts (Prompt Engineering). Tu objetivo es evaluar el prompt que ha creado un usuario para ver si es efectivo.

El usuario ha intentado seguir la estructura de 5 elementos: Contexto, Rol, Tarea, Formato y Tono.

A continuación te presento el PROMPT DEL USUARIO:
"""
$userPrompt
"""

TU TAREA DE EVALUACIÓN:
1. Analiza si el prompt es claro, específico y no deja lugar a alucinaciones.
2. El prompt estará dividido en Contexto, Rol, Tarea, Formato y Tono. Analiza que estos puntos se hayan deifindo correctamente y sean adecuados para el objetivo general.
Si alguno de estos puntos es ambiguo o podría mejorarse, indícalo claramente sin rodeos.
3. Asigna una PUNTUACIÓN del 0 al 100 basándote en la probabilidad de obtener un resultado excelente.
4. CRITERIO DE ÉXITO: Si la puntuación es superior a 70, se considera un prompt "Completo y Efectivo".

FORMATO DE TU RESPUESTA:
- Empieza con una línea en negrita indicando la puntuación: **Puntuación: X/100**.
- Si la puntuación es > 70: Felicita al usuario, dile que su prompt está listo para usarse y explica brevemente por qué es bueno. Si hay alguna mejora menor, indícasela.
- Si la puntuación es <= 70: Sé amable pero crítica. Explica qué le falta (ej. "El contexto es muy vago" o "No definiste bien el formato de salida") y dale un ejemplo concreto de cómo arreglar esa parte específica.
- Termina con una frase motivadora.
''';

      final buffer = StringBuffer();

      _streamSubscription = _geminiService.generateContentStream(evaluationPrompt).listen(
        (chunk) {
          buffer.write(chunk);
        },
        onDone: () {
          if (!mounted) return;

          _messages.removeLast();
          setState(() {
            _geminiReturned = true;
          });

          _addMessage(
            _ChatMessage(
              text: buffer.toString(),
              isUser: false,
              isAnimated: true,
              onComplete: () {
                if (!mounted) return;
                setState(() {
                  _responseAnimationComplete = true;
                  _isTyping = false;
                });
              },
            ),
          );
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _responseAnimationComplete = false;
            _geminiReturned = false;
            _isTyping = false;
          });
          _messages.removeLast();
          _addMessage(
            _ChatMessage(
              text: 'Error al evaluar el prompt: $e\n\nPor favor, intenta de nuevo.',
              isUser: false,
              isAnimated: false,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _responseAnimationComplete = false;
        _geminiReturned = false;
        _isTyping = false;
      });
      _messages.removeLast();
      _addMessage(
        _ChatMessage(
          text: 'Error al evaluar el prompt: $e\n\nPor favor, intenta de nuevo.',
          isUser: false,
          isAnimated: false,
        ),
      );
    }
  }

  Future<void> _saveConversation() async {
    final messageEntities = _messages.map((chatMsg) {
      return MessageEntity(
        id: '${_conversationId}_${DateTime.now().millisecondsSinceEpoch}',
        content: chatMsg.text,
        type: chatMsg.isUser ? MessageTypeEntity.user : MessageTypeEntity.bot,
        timestamp: DateTime.now(),
      );
    }).toList();

    await widget.conversationRepository.saveConversation(messageEntities, suffix: 'modulo2');
  }

  void _restart() {
    _introTimer?.cancel();
    setState(() {
      _messages.clear();
      _promptParts.forEach((key, _) => _promptParts[key] = '');
      _currentPartIndex = 0;
      _waitingForInput = false;
      _promptComplete = false;
      _geminiReturned = false;
      _responseAnimationComplete = false;
      _isTyping = false;
      _conversationId = 'modulo2_${DateTime.now().millisecondsSinceEpoch}';
    });
    _startConversation();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Estructura de un buen prompt',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_isTyping)
                TextButton(
                  onPressed: _skipCurrentAnimation,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Saltar', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        if (_waitingForInput && !_promptComplete)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).round()),
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
        if (!_waitingForInput && _promptComplete && !_responseAnimationComplete)
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
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                color: message.isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer,
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

  Widget _buildMessageContent(ThemeData theme, _ChatMessage message) {
    if (message.isAnimated) {
      return _AnimatedText(
        text: message.text,
        skipStream: _skipSignal.stream,
        onComplete: () {
          message.onComplete?.call();
          _handleMessageComplete();
        },
      );
    }

    return _buildStaticContent(theme, message.text);
  }

  Widget _buildStaticContent(ThemeData theme, String text) {
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

    if (looksLikeMarkdown(text)) {
      return MarkdownWidget(
        data: cleanMarkdownText(text),
        shrinkWrap: true,
        selectable: true,
        config: MarkdownConfig(
          configs: [
            PConfig(textStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15, height: 1.4)),
            CodeConfig(
                style: TextStyle(
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                    fontSize: 14)),
          ],
        ),
      );
    }

    return SelectableText(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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
  final Stream<void>? skipStream;

  const _AnimatedText({
    required this.text,
    this.onComplete,
    this.skipStream,
  });

  @override
  State<_AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<_AnimatedText> {
  String _displayedText = '';
  Timer? _timer;
  bool _isFinished = false;
  StreamSubscription? _skipSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.skipStream != null) {
      _skipSubscription = widget.skipStream!.listen((_) {
        _finishImmediately();
      });
    }
    _animateText();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _skipSubscription?.cancel();
    super.dispose();
  }

  void _finishImmediately() {
    if (_isFinished) return;
    _timer?.cancel();
    setState(() {
      _displayedText = widget.text;
      _isFinished = true;
    });
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
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
        _isFinished = true;
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return _buildStaticContent(Theme.of(context), widget.text);
    }

    return GestureDetector(
      onTap: _finishImmediately,
      child: SelectableText(
        _displayedText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
      ),
    );
  }

  Widget _buildStaticContent(ThemeData theme, String text) {
    bool looksLikeMarkdown(String t) {
      if (t.contains('```')) return true;
      if (t.contains('\n- ') || t.contains('\n* ') || t.contains('\n1. ')) return true;
      if (RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(t)) return true;
      return false;
    }

    if (looksLikeMarkdown(text)) {
      return MarkdownWidget(
        data: text,
        shrinkWrap: true,
        selectable: true,
        config: MarkdownConfig(
          configs: [
            PConfig(textStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15, height: 1.4)),
            CodeConfig(
                style: TextStyle(
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                    fontSize: 14)),
          ],
        ),
      );
    }

    return SelectableText(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }
}