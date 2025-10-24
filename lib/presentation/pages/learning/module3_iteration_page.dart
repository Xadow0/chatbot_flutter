import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../data/services/gemini_service.dart';
import 'package:markdown_widget/markdown_widget.dart';

enum IterationType { reformular, aclarar, ejemplificar, acotar }

class Module3IterationPage extends StatefulWidget {
  /// If [iterationSequence] is provided the page will run through each IterationType
  /// in order within the same chat interface. By default it runs all four types.
  final List<IterationType>? iterationSequence;
  final VoidCallback onNext; // called when the entire sequence finishes

  const Module3IterationPage({
    super.key,
    this.iterationSequence,
    required this.onNext,
  });

  @override
  State<Module3IterationPage> createState() => _Module3IterationPageState();
}

class _Module3IterationPageState extends State<Module3IterationPage> {
  late final List<IterationType> _sequence;
  int _currentIterationIndex = 0;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();

  final List<_ChatMessage> _messages = [];
  bool _waitingForUserInput = false;
  bool _generatingResponse = false;
  bool _exerciseComplete = false;

  String? _conversationId;
  String? _originalPrompt;

  @override
  void initState() {
    super.initState();
    _sequence = widget.iterationSequence ?? [IterationType.reformular, IterationType.aclarar, IterationType.ejemplificar, IterationType.acotar];
    _conversationId = 'modulo3_${_sequence.map((e) => e.name).join('_')}_${DateTime.now().millisecondsSinceEpoch}';
    _startExercise();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startExercise() async {
    await _addMessage(_ChatMessage(
      text: _getTitleText(),
      isUser: false,
      isAnimated: true,
      isTitle: true,
    ));

    await Future.delayed(const Duration(milliseconds: 300));
    await _startConversationFlow();
  }

  String _getTitleText() {
    final current = _sequence[_currentIterationIndex];
    switch (current) {
      case IterationType.reformular:
        return 'Aprende a Iterar: Reformular';
      case IterationType.aclarar:
        return 'Aprende a Iterar: Aclarar';
      case IterationType.ejemplificar:
        return 'Aprende a Iterar: Ejemplificar';
      case IterationType.acotar:
        return 'Aprende a Iterar: Acotar';
    }
  }

  Future<void> _startConversationFlow() async {
    final data = _getFlowData();

    await Future.delayed(const Duration(milliseconds: 500));
    await _addMessage(_ChatMessage(
      text: data['userPrompt']!,
      isUser: true,
      isAnimated: true,
    ));
    _originalPrompt = data['userPrompt'];

    await Future.delayed(const Duration(milliseconds: 300));
    await _addMessage(_ChatMessage(
      text: data['botResponse']!,
      isUser: false,
      isAnimated: true,
    ));

    await Future.delayed(const Duration(milliseconds: 300));
    await _addMessage(_ChatMessage(
      text: data['userObservation']!,
      isUser: true,
      isAnimated: true,
    ));

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _waitingForUserInput = true);
  }

  Map<String, String> _getFlowData() {
    final current = _sequence[_currentIterationIndex];
    switch (current) {
      case IterationType.reformular:
        return {
          'userPrompt': 'Realiza un texto corto sobre el cambio climático',
          'botResponse':
              'El cambio climático es un fenómeno global que afecta a nuestro planeta. '
              'Las temperaturas están aumentando debido a las emisiones de gases de efecto invernadero. '
              'Los océanos se están calentando y el nivel del mar está subiendo. '
              'Los patrones climáticos están cambiando, causando eventos extremos más frecuentes. '
              'La biodiversidad se ve amenazada por estos cambios. '
              'Las actividades humanas, especialmente la quema de combustibles fósiles, son la principal causa. '
              'Los científicos advierten que necesitamos actuar con urgencia. '
              'La transición a energías renovables es fundamental. '
              'Cada persona puede contribuir con pequeñas acciones diarias. '
              'El futuro del planeta depende de las decisiones que tomemos hoy.',
          'userObservation':
              'No es un mal texto, pero esto no me sirve para mi presentación, necesito algo más directo. '
              'Debo indicar a la IA que mi texto es para una presentación y el tono que debe tener.',
        };
      case IterationType.aclarar:
        return {
          'userPrompt': 'Explícame qué es la inteligencia artificial',
          'botResponse':
              'La inteligencia artificial es un campo de la informática que se enfoca en crear sistemas '
              'capaces de realizar tareas que normalmente requieren inteligencia humana. Utiliza algoritmos '
              'y modelos para procesar información y tomar decisiones.',
          'userObservation':
              'Entiendo la idea general, pero es demasiado técnico. Necesito que me lo expliques '
              'de manera más simple, como si se lo explicaras a un niño de 10 años.',
        };
      case IterationType.ejemplificar:
        return {
          'userPrompt': 'Cuéntame sobre la fotosíntesis',
          'botResponse':
              'La fotosíntesis es el proceso mediante el cual las plantas convierten la luz solar, '
              'el dióxido de carbono y el agua en glucosa y oxígeno. Es fundamental para la vida '
              'en la Tierra ya que produce el oxígeno que respiramos.',
          'userObservation':
              'Está bien explicado, pero me gustaría que lo acompañaras con un ejemplo concreto '
              'de cómo sucede esto en una planta común, como un girasol.',
        };
      case IterationType.acotar:
        return {
          'userPrompt': 'Háblame sobre la historia de la música',
          'botResponse':
              'La historia de la música es vastísima y abarca miles de años. Desde los primeros instrumentos '
              'prehistóricos hasta la música electrónica moderna, ha evolucionado constantemente. Cada cultura '
              'ha desarrollado sus propios estilos, instrumentos y teorías musicales. La música clásica europea, '
              'el jazz americano, las músicas tradicionales de Asia y África, el rock, el pop, el hip-hop... '
              'cada género tiene su propia historia fascinante.',
          'userObservation':
              'Es demasiado amplio. Necesito que te centres específicamente en la música clásica europea '
              'del periodo barroco, entre 1600 y 1750.',
        };
    }
  }

  /// Adds a message and waits for its animation to complete if animated.
  Future<void> _addMessage(_ChatMessage message) async {
    if (!mounted) return;

    if (message.isAnimated) message.animationCompleter = Completer<void>();

    setState(() => _messages.add(message));
    _scrollToBottom();
    await _saveConversation();

    if (message.isAnimated) {
      try {
        await message.animationCompleter?.future.timeout(Duration(milliseconds: _computeTimeoutForText(message.text)));
      } catch (_) {}
    } else {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  int _computeTimeoutForText(String text) {
    final length = text.length;
    final perChar = (20 - (length / 50)).clamp(3, 20).toInt();
    final total = (length * perChar) + 500;
    return total.clamp(800, 30000);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendUserMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _addMessage(_ChatMessage(text: text, isUser: true, isAnimated: false));
    _messageController.clear();

    setState(() {
      _waitingForUserInput = false;
      _generatingResponse = true;
    });

    await _addMessage(_ChatMessage(text: 'Generando respuesta...', isUser: false, isAnimated: false));

    try {
      final completePrompt = '$_originalPrompt. $text';
      final response = await _geminiService.generateContent(completePrompt);

      if (!mounted) return;
      setState(() => _generatingResponse = false);

      if (_messages.isNotEmpty) {
        _messages.removeLast();
        setState(() {});
      }

      await _addMessage(_ChatMessage(text: response, isUser: false, isAnimated: true));
      if (mounted) {
        // mark this iteration complete
        setState(() => _exerciseComplete = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingResponse = false);
      if (_messages.isNotEmpty) {
        _messages.removeLast();
        setState(() {});
      }
      await _addMessage(_ChatMessage(text: 'Error al generar respuesta: $e\n\nPor favor, intenta de nuevo.', isUser: false, isAnimated: false));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
      setState(() => _waitingForUserInput = true);
    }
  }

  Future<void> _saveConversation() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final conversationsDir = Directory('${directory.path}/conversations/modulo3');
      if (!await conversationsDir.exists()) await conversationsDir.create(recursive: true);
      final file = File('${conversationsDir.path}/$_conversationId.json');
      final conversationData = {
        'id': _conversationId,
        'module': 'modulo3',
        'iterationSequence': _sequence.map((e) => e.name).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'messages': _messages.map((m) => {'text': m.text, 'isUser': m.isUser, 'isTitle': m.isTitle}).toList(),
        'completed': _exerciseComplete
      };
      await file.writeAsString(jsonEncode(conversationData));
    } catch (e) {
      // ignore: avoid_print
      print('Error al guardar conversación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              if (message.isTitle) return _buildTitleMessage(theme, message);
              return _buildMessageBubble(theme, message);
            },
          ),
        ),
        if (_exerciseComplete && !_generatingResponse)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                // Move to next iteration in the same chat if available
                if (_currentIterationIndex < _sequence.length - 1) {
                  setState(() {
                    _currentIterationIndex++;
                    _exerciseComplete = false;
                    _waitingForUserInput = false;
                  });
                  // add the next title and start its flow
                  await _addMessage(_ChatMessage(text: _getTitleText(), isUser: false, isAnimated: true, isTitle: true));
                  await Future.delayed(const Duration(milliseconds: 300));
                  await _startConversationFlow();
                } else {
                  // last iteration finished: call parent completion
                  widget.onNext();
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: Text(_currentIterationIndex < _sequence.length - 1 ? 'Siguiente paso' : 'Finalizar módulo'),
            ),
          ),
          if (_waitingForUserInput && !_exerciseComplete)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).round()), blurRadius: 4, offset: const Offset(0, -2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu turno: ${_getPromptHint()}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(hintText: 'Escribe tu mensaje...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendUserMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: _sendUserMessage, icon: Icon(Icons.send, color: theme.colorScheme.primary), style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primaryContainer, padding: const EdgeInsets.all(12))),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getPromptHint() {
    final current = _sequence[_currentIterationIndex];
    switch (current) {
      case IterationType.reformular:
        return 'Reformula el prompt indicando el contexto y tono';
      case IterationType.aclarar:
        return 'Pide una explicación más simple';
      case IterationType.ejemplificar:
        return 'Solicita un ejemplo concreto';
      case IterationType.acotar:
        return 'Limita el tema a un periodo específico';
    }
  }

  Widget _buildTitleMessage(ThemeData theme, _ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]), borderRadius: BorderRadius.circular(20)),
          child: message.isAnimated
              ? _AnimatedText(
                  text: message.text,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  onComplete: () {
                    // mark animation complete and signal awaiting code
                    message.animationCompleter?.complete();
                    if (mounted) setState(() => message.isAnimated = false);
                  },
                )
              : Text(message.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ThemeData theme, _ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[CircleAvatar(backgroundColor: theme.colorScheme.secondaryContainer, radius: 16, child: Icon(Icons.smart_toy, size: 18, color: theme.colorScheme.onSecondaryContainer)), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: message.isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: _buildMessageContent(theme, message),
            ),
          ),
          if (message.isUser) ...[const SizedBox(width: 8), CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, radius: 16, child: Icon(Icons.person, size: 18, color: theme.colorScheme.onPrimaryContainer))],
        ],
      ),
    );
  }

  // Decide how to render the message content: animated plain text, selectable plain text,
  // or a Markdown widget if the text looks like markdown/code (for Gemini responses).
  Widget _buildMessageContent(ThemeData theme, _ChatMessage message) {
    final text = message.text;

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
      // If this message was animating, stop animation and persist it as static markdown
      if (message.isAnimated) {
        message.animationCompleter?.complete();
        message.isAnimated = false;
      }
      return MarkdownWidget(
        data: cleanMarkdownText(text),
        shrinkWrap: true,
        selectable: true,
        config: MarkdownConfig(),
      );
    }

    if (message.isAnimated) {
      return _AnimatedText(
        text: text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        onComplete: () {
          // mark animation complete so it won't re-animate when scrolled
          message.animationCompleter?.complete();
          if (mounted) setState(() => message.isAnimated = false);
        },
      );
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
  bool isAnimated; // mutable so we can mark it completed
  final bool isTitle;

  Completer<void>? animationCompleter;

  _ChatMessage({required this.text, required this.isUser, this.isAnimated = false, this.isTitle = false});
}

class _AnimatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final VoidCallback? onComplete;

  const _AnimatedText({required this.text, this.style, this.onComplete});

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
    final totalLength = widget.text.length;
    final perCharDelay = (18 - (totalLength / 50)).clamp(2, 18).toInt();

    int charIndex = 0;
    _timer = Timer.periodic(Duration(milliseconds: perCharDelay), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (charIndex < widget.text.length) {
        setState(() {
          _displayedText = widget.text.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 120), () {
          widget.onComplete?.call();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      _displayedText,
      style: widget.style ?? Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }
}
