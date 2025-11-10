import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class Module1Page extends StatefulWidget {
  const Module1Page({super.key});

  @override
  State<Module1Page> createState() => _Module1PageState();
}

class _Module1PageState extends State<Module1Page> {
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
    await prefs.setBool('module_1_completed', true);
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
        return _CommunicationPage(onNext: _nextPage);
      case 2:
        return _ExplanationPage(onNext: _nextPage);
      case 3:
        return _CapabilitiesQuizPage(onFinish: _completeModule);
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
            Icons.psychology_outlined,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            '¿Cómo funciona la IA?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Descubre los fundamentos básicos de la Inteligencia Artificial',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
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

// ============= PÁGINA DE COMUNICACIÓN (ANIMACIÓN) =============
class _CommunicationPage extends StatefulWidget {
  final VoidCallback onNext;

  const _CommunicationPage({required this.onNext});

  @override
  State<_CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<_CommunicationPage> {
  String _displayedExplanation = '';
  final String _fullExplanation = 
      'La IA Generativa no busca información ni posee conocimiento propio, '
      'genera contenido nuevo palabra por palabra, eligiendo en cada paso la palabra más probable según el contexto. '
      'No escribe todo de golpe: va construyendo la respuesta paso a paso, evaluando múltiples candidatas antes de elegir la mejor para cada caso. '
      'Su función es crear contenido nuevo (texto, imágenes o sonido) a partir de los patrones y relaciones que aprendió durante su entrenamiento, con grandes cantidades de datos. ';
  
  bool _explanationComplete = false;
  bool _showStartButton = false;
  bool _isGenerating = false;
  bool _generationComplete = false;
  
  final List<String> _targetWords = [
    'La', 'IA', 'genera', 'texto', 'prediciendo', 'la', 'palabra',
    'más', 'probable', 'en', 'cada', 'momento'
  ];
  
  final List<String> _generatedWords = [];
  String _currentWord = '';
  List<String> _candidateWords = [];
  int _wordIndex = 0;

  @override
  void initState() {
    super.initState();
    _startExplanationAnimation();
  }

  void _startExplanationAnimation() {
    int charIndex = 0;
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < _fullExplanation.length) {
        setState(() {
          _displayedExplanation = _fullExplanation.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _explanationComplete = true;
        });
        // Mostrar el botón después de completar la explicación
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showStartButton = true;
            });
          }
        });
      }
    });
  }

  void _startWordGeneration() {
    setState(() {
      _showStartButton = false;
      _isGenerating = true;
    });
    _generateNextWord();
  }

  void _generateNextWord() {
    if (_wordIndex >= _targetWords.length) {
      setState(() {
        _isGenerating = false;
        _generationComplete = true;
      });
      return;
    }

    final targetWord = _targetWords[_wordIndex];
    _candidateWords = _generateCandidates(targetWord);

    int candidateIndex = 0;

    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (candidateIndex < _candidateWords.length) {
        setState(() {
          _currentWord = _candidateWords[candidateIndex];
        });
        candidateIndex++;
      } else {
        timer.cancel();
        setState(() {
          _generatedWords.add(targetWord);
          _currentWord = '';
          _candidateWords = [];
          _wordIndex++;
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          _generateNextWord();
        });
      }
    });
  }

  List<String> _generateCandidates(String target) {
    final random = Random();
    final allWords = [
      'el', 'la', 'un', 'texto', 'código', 'imagen', 'datos',
      'genera', 'crea', 'produce', 'escribe', 'hace',
      'inteligencia', 'sistema', 'algoritmo', 'modelo',
      'artificial', 'natural', 'sintética', 'humana',
      'prediciendo', 'calculando', 'procesando', 'analizando',
      'palabra', 'frase', 'oración', 'término',
      'probable', 'posible', 'correcta', 'adecuada',
      'en', 'con', 'por', 'para',
      'cada', 'todo', 'este', 'ese',
      'momento', 'instante', 'caso', 'situación',
    ];
    
    final candidates = <String>[];
    final otherWords = allWords.where((w) => w != target).toList()..shuffle(random);
    
    for (int i = 0; i < 4; i++) {
      candidates.add(otherWords[i]);
    }
    
    candidates.add(target);
    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '¿Cómo se comunica contigo?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Explicación animada
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _displayedExplanation,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Simulación de generación
          if (_explanationComplete) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showStartButton || _isGenerating || _generationComplete
                        ? 'Generación en tiempo real:'
                        : '',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (_showStartButton || _isGenerating || _generationComplete)
                    const SizedBox(height: 12),
                  
                  // Botón para comenzar la animación
                  if (_showStartButton) ...[
                    Text(
                      'Presione el botón para simular una generación de texto en tiempo real como lo haría una IA:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _startWordGeneration,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Comenzar Animación'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Texto generado
                  if (_isGenerating || _generationComplete)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ..._generatedWords.map((word) => Text(
                          '$word ',
                          style: theme.textTheme.bodyLarge,
                        )),
                        if (_currentWord.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _currentWord,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        if (_isGenerating && _currentWord.isEmpty)
                          Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(left: 4),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  
                  if (_candidateWords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Candidatas:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _candidateWords.map((word) {
                        final isSelected = word == _currentWord;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withAlpha((0.1 * 255).round())
                                : theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withAlpha((0.3 * 255).round()),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            word,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          const Spacer(),
          
          // Botón continuar
          if (_generationComplete)
            ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Continuar'),
            ),
        ],
      ),
    );
  }
}

// ============= CLASE PARA OPCIONES DE QUIZ CON EXPLICACIÓN =============
class _QuizOption {
  final String text;
  final bool isCorrect;
  final String explanation;

  _QuizOption({
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });
}

// ============= PÁGINA DE EXPLICACIÓN + QUIZ =============
class _ExplanationPage extends StatefulWidget {
  final VoidCallback onNext;

  const _ExplanationPage({required this.onNext});

  @override
  State<_ExplanationPage> createState() => _ExplanationPageState();
}

class _ExplanationPageState extends State<_ExplanationPage> {
  String _displayedText = '';
  final String _fullText = 
      'Como hemos visto en este funcionamiento, la IA Generativa crea contenido en base a su aprendizaje, por lo que hay que tener claras sus capacidades y limitaciones. '
      'Podrá generar contenido nuevo, ayudarte con ideas, redactar textos, crear imágenes y más, pero siempre basándose en patrones aprendidos y sin comprensión real del mundo. '
      'No podrá tener opiniones propias, ni acceder a información en tiempo real, ni ejecutar acciones fuera de generar texto o contenido para el que haya sido entrenada. ';
  
  bool _showQuiz = false;
  int? _selectedAnswer;
  bool _answeredCorrectly = false;
  bool _showExplanations = false;
  
  List<_QuizOption> _quizOptions = [];

  @override
  void initState() {
    super.initState();
    _startTextAnimation();
  }

  void _startTextAnimation() {
    int charIndex = 0;
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < _fullText.length) {
        setState(() {
          _displayedText = _fullText.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        Future.delayed(const Duration(seconds: 1), () {
          setState(() {
            _showQuiz = true;
          });
          _generateQuizOptions();
        });
      }
    });
  }

  void _generateQuizOptions() {
    final correctOptions = [
      _QuizOption(
        text: 'Predice la mejor respuesta posible',
        isCorrect: true,
        explanation:
            'Correcto. La IA funciona prediciendo la continuación más probable del texto basándose en los patrones aprendidos durante su entrenamiento.',
      ),
      _QuizOption(
        text: 'Genera texto según patrones estadísticos',
        isCorrect: true,
        explanation:
            'Correcto. Los modelos generativos producen texto según patrones estadísticos aprendidos de grandes volúmenes de datos.',
      ),
      _QuizOption(
        text: 'Produce respuestas basadas en ejemplos previos del entrenamiento',
        isCorrect: true,
        explanation:
            'Correcto. La IA genera respuestas basadas en los ejemplos y estructuras de lenguaje que aprendió durante su entrenamiento.',
      ),
      _QuizOption(
        text: 'Calcula la probabilidad de qué palabra viene después',
        isCorrect: true,
        explanation:
            'Correcto. El modelo de lenguaje predice la siguiente palabra más probable a partir del contexto anterior.',
      ),
    ];

    final incorrectOptions = [
      _QuizOption(
        text: 'Busca en Internet información actualizada',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA generativa no busca en Internet en tiempo real. Trabaja únicamente con los patrones aprendidos durante su entrenamiento.',
      ),
      _QuizOption(
        text: 'Recuerda tus conversaciones anteriores',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no tiene memoria a largo plazo de conversaciones anteriores. Solo mantiene el contexto de la conversación actual.',
      ),
      _QuizOption(
        text: 'Comprende emociones humanas reales',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA puede reconocer patrones emocionales en el texto, pero no experimenta ni comprende emociones como los humanos.',
      ),
      _QuizOption(
        text: 'Aprende de lo que le dices en el momento',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no aprende de las conversaciones individuales. Su aprendizaje ocurrió durante el entrenamiento previo.',
      ),
      _QuizOption(
        text: 'Decide según lo que considera más justo',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no tiene juicios morales propios. Simplemente predice respuestas basándose en patrones de los datos de entrenamiento.',
      ),
      _QuizOption(
        text: 'Siente empatía por el usuario',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no puede sentir empatía ni ninguna emoción. Solo genera respuestas que parecen empáticas basándose en patrones.',
      ),
      _QuizOption(
        text: 'Ejecuta comandos directamente en tu dispositivo',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA generativa solo produce texto como salida. No ejecuta comandos ni tiene acceso directo a tu dispositivo.',
      ),
      _QuizOption(
        text: 'Busca una solución exacta a cada problema',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no busca soluciones exactas. Genera respuestas probabilísticas basadas en patrones, lo que significa que puede cometer errores.',
      ),
      _QuizOption(
        text: 'Accede a una base de datos de respuestas predefinidas',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no tiene respuestas predefinidas. Genera cada respuesta de forma dinámica basándose en el contexto y los patrones aprendidos.',
      ),
      _QuizOption(
        text: 'Piensa como un humano antes de responder',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no "piensa" en el sentido humano. Realiza cálculos matemáticos complejos para predecir la siguiente secuencia de tokens.',
      ),
      _QuizOption(
        text: 'Tiene opiniones personales sobre temas',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no tiene opiniones personales. Las respuestas que genera reflejan patrones de sus datos de entrenamiento, no creencias propias.',
      ),
      _QuizOption(
        text: 'Consulta expertos en tiempo real',
        isCorrect: false,
        explanation:
            'Incorrecto. La IA no consulta a expertos ni a ninguna fuente externa. Genera respuestas únicamente basándose en su entrenamiento.',
      ),
    ];

    final random = Random();
    final selectedCorrect = (correctOptions..shuffle(random)).first;
    final selectedIncorrect = (incorrectOptions..shuffle(random)).take(2).toList();

    setState(() {
      _quizOptions = [selectedCorrect, ...selectedIncorrect]..shuffle();
    });
  }

  void _selectAnswer(int index) {
    if (_showExplanations) return;
    
    setState(() {
      _selectedAnswer = index;
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_quizOptions[index].isCorrect) {
        setState(() {
          _answeredCorrectly = true;
          _showExplanations = true;
        });
      } else {
        setState(() {
          _showExplanations = true;
        });
      }
    });
  }

  void _retryQuiz() {
    setState(() {
      _selectedAnswer = null;
      _answeredCorrectly = false;
      _showExplanations = false;
    });
    _generateQuizOptions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '¿Cómo funciona?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _displayedText,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (_showQuiz) ...[
            Text(
              '¿Qué hace la IA cuando le haces una pregunta?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView.builder(
                itemCount: _quizOptions.length,
                itemBuilder: (context, index) {
                  final option = _quizOptions[index];
                  final isSelected = _selectedAnswer == index;
                  final showAsCorrect = _showExplanations && _answeredCorrectly && option.isCorrect;
                  final showAsIncorrect = _showExplanations && isSelected && !option.isCorrect;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _showExplanations ? null : () => _selectAnswer(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: showAsCorrect
                                  ? Colors.green.withAlpha((0.1 * 255).round())
                                  : showAsIncorrect
                                      ? Colors.red.withAlpha((0.1 * 255).round())
                                      : isSelected
                                          ? theme.colorScheme.primaryContainer.withAlpha((0.5 * 255).round())
                                          : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: showAsCorrect
                                    ? Colors.green
                                    : showAsIncorrect
                                        ? Colors.red
                                        : isSelected
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.text,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                                if (showAsCorrect)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                else if (showAsIncorrect)
                                  const Icon(Icons.cancel, color: Colors.red, size: 24),
                              ],
                            ),
                          ),
                        ),
                        
                        if (_showExplanations && (_answeredCorrectly || isSelected)) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_answeredCorrectly && option.isCorrect)
                                  ? Colors.green.withAlpha((0.05 * 255).round())
                                  : Colors.red.withAlpha((0.05 * 255).round()),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (_answeredCorrectly && option.isCorrect)
                                    ? Colors.green.withAlpha((0.3 * 255).round())
                                    : Colors.red.withAlpha((0.3 * 255).round()),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  (_answeredCorrectly && option.isCorrect) ? Icons.lightbulb : Icons.info_outline,
                                  size: 20,
                                  color: (_answeredCorrectly && option.isCorrect) ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    option.explanation,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_showExplanations)
              Row(
                children: [
                  if (!_answeredCorrectly)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _retryQuiz,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ),
                  if (!_answeredCorrectly) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _answeredCorrectly ? widget.onNext : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: _answeredCorrectly ? Colors.green : null,
                        foregroundColor: _answeredCorrectly ? Colors.white : null,
                      ),
                      child: Text(_answeredCorrectly ? 'Continuar' : 'Responde correctamente para continuar'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ============= CLASE PARA PREGUNTAS DE CAPACIDADES =============
class _CapabilityQuestion {
  final String text;
  final bool canDo;
  final String explanation;

  _CapabilityQuestion(this.text, this.canDo, this.explanation);
}

// ============= PÁGINA DE QUIZ DE CAPACIDADES =============
class _CapabilitiesQuizPage extends StatefulWidget {
  final VoidCallback onFinish;

  const _CapabilitiesQuizPage({required this.onFinish});

  @override
  State<_CapabilitiesQuizPage> createState() => _CapabilitiesQuizPageState();
}

class _CapabilitiesQuizPageState extends State<_CapabilitiesQuizPage> {
  final List<_CapabilityQuestion> _allQuestions = [
    _CapabilityQuestion(
      'Resumir un texto',
      true,
      'Correcto. La IA puede analizar textos largos y generar resúmenes coherentes identificando las ideas principales.',
    ),
    _CapabilityQuestion(
      'Comprobar si algo es 100% falso',
      false,
      'Incorrecto. La IA no puede verificar hechos con certeza absoluta. Trabaja con probabilidades y puede cometer errores o ser engañada.',
    ),
    _CapabilityQuestion(
      'Juzgar si algo está bien o mal moralmente',
      false,
      'Incorrecto. La IA no tiene capacidad de juicio moral propio. Puede reflejar valores de sus datos de entrenamiento, pero no comprende la moralidad.',
    ),
    _CapabilityQuestion(
      'Garantizar información correcta',
      false,
      'Incorrecto. Dado que la IA funciona prediciendo respuestas por probabilidad, nunca puede asegurar un 100% de acierto. Puede generar información incorrecta o inventada.',
    ),
    _CapabilityQuestion(
      'Traducir una frase a otro idioma',
      true,
      'Correcto. La IA puede traducir textos entre múltiples idiomas basándose en los patrones lingüísticos aprendidos.',
    ),
    _CapabilityQuestion(
      'Generar un guión',
      true,
      'Correcto. La IA puede crear contenido narrativo como guiones, historias y diálogos de forma coherente.',
    ),
    _CapabilityQuestion(
      'Crear una imagen a partir de una descripción',
      true,
      'Correcto. Los modelos de IA generativa de imágenes pueden crear imágenes nuevas basándose en descripciones de texto.',
    ),
    _CapabilityQuestion(
      'Dar una opinión personal',
      false,
      'Incorrecto. La IA no tiene opiniones personales ni experiencias propias. Solo simula respuestas basadas en patrones de datos.',
    ),
    _CapabilityQuestion(
      'Escribir código de programación',
      true,
      'Correcto. La IA puede generar código en diversos lenguajes de programación basándose en los patrones aprendidos de repositorios de código.',
    ),
    _CapabilityQuestion(
      'Predecir el futuro con certeza',
      false,
      'Incorrecto. La IA no puede predecir el futuro con certeza. Solo puede hacer estimaciones basadas en patrones históricos, que pueden ser inexactos.',
    ),
    _CapabilityQuestion(
      'Entender el contexto de una conversación',
      true,
      'Correcto. La IA puede mantener y comprender el contexto de una conversación para generar respuestas coherentes.',
    ),
    _CapabilityQuestion(
      'Tener conciencia de sí misma',
      false,
      'Incorrecto. La IA no tiene conciencia ni autoconocimiento. Es un sistema de procesamiento de patrones sin experiencia subjetiva.',
    ),
  ];

  List<_CapabilityQuestion> _questions = [];
  Map<int, bool?> _answers = {};
  bool _showResults = false;
  int _correctAnswers = 0;
  String _introText = '';
  bool _introComplete = false;
  final String _fullIntroText = 'Para terminar, vamos a hacer un ejercicio de pensar qué puede y no puede hacer una IA. Marca en cada opción la que consideres correcta:';

  @override
  void initState() {
    super.initState();
    _questions = (_allQuestions..shuffle()).take(5).toList();
    _startIntroAnimation();
  }

  void _startIntroAnimation() {
    int charIndex = 0;
    Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (charIndex < _fullIntroText.length) {
        setState(() {
          _introText = _fullIntroText.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _introComplete = true;
        });
      }
    });
  }

  void _submitAnswers() {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].canDo) {
        correct++;
      }
    }
    setState(() {
      _correctAnswers = correct;
      _showResults = true;
    });
  }

  void _retryQuiz() {
    setState(() {
      _questions = (_allQuestions..shuffle()).take(5).toList();
      _answers = {};
      _showResults = false;
      _correctAnswers = 0;
      _introText = '';
      _introComplete = false;
    });
    _startIntroAnimation();
  }

  bool get _allAnswered => _answers.length == _questions.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '¿Qué puede hacer la IA?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          if (!_showResults)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha((0.3 * 255).round()),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _introText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            )
          else if (_correctAnswers == _questions.length)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '¡Felicidades!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Has completado el módulo correctamente con $_correctAnswers/${_questions.length} respuestas correctas.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Al presionar "Finalizar" volverás al menú de módulos y podrás continuar con el siguiente.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Resultado: $_correctAnswers/${_questions.length} correctas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final question = _questions[index];
                final userAnswer = _answers[index];
                final isCorrect = userAnswer == question.canDo;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _showResults
                              ? (isCorrect
                                  ? Colors.green.withAlpha((0.1 * 255).round())
                                  : Colors.red.withAlpha((0.1 * 255).round()))
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: _showResults
                              ? Border.all(
                                  color: isCorrect ? Colors.green : Colors.red,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    question.text,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_showResults)
                                  Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: isCorrect ? Colors.green : Colors.red,
                                    size: 24,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _OptionButton(
                                    label: 'PUEDE',
                                    isSelected: userAnswer == true,
                                    isCorrect: _showResults ? question.canDo : null,
                                    enabled: !_showResults,
                                    onTap: () {
                                      if (!_showResults) {
                                        setState(() {
                                          _answers[index] = true;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _OptionButton(
                                    label: 'NO PUEDE',
                                    isSelected: userAnswer == false,
                                    isCorrect: _showResults ? !question.canDo : null,
                                    enabled: !_showResults,
                                    onTap: () {
                                      if (!_showResults) {
                                        setState(() {
                                          _answers[index] = false;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      if (_showResults) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.withAlpha((0.05 * 255).round())
                                : Colors.red.withAlpha((0.05 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green.withAlpha((0.3 * 255).round())
                                  : Colors.red.withAlpha((0.3 * 255).round()),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCorrect ? Icons.lightbulb : Icons.info_outline,
                                size: 20,
                                color: isCorrect ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question.explanation,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withAlpha((0.8 * 255).round()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (!_showResults)
            ElevatedButton(
              onPressed: _allAnswered ? _submitAnswers : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(_allAnswered ? 'Corregir' : 'Responde todas las preguntas'),
            )
          else
            Row(
              children: [
                if (_correctAnswers < _questions.length)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retryQuiz,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ),
                if (_correctAnswers < _questions.length) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _correctAnswers == _questions.length ? widget.onFinish : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: _correctAnswers == _questions.length ? Colors.green : null,
                      foregroundColor: _correctAnswers == _questions.length ? Colors.white : null,
                    ),
                    child: Text(_correctAnswers == _questions.length ? 'Finalizar Módulo' : 'Responde todo correctamente'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============= BOTÓN DE OPCIÓN PERSONALIZADO =============
class _OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool? isCorrect;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    
    if (isCorrect != null) {
      if (isCorrect!) {
        backgroundColor = Colors.green.withAlpha((0.1 * 255).round());
        borderColor = Colors.green;
        textColor = Colors.green;
      } else if (isSelected && !isCorrect!) {
        backgroundColor = Colors.red.withAlpha((0.1 * 255).round());
        borderColor = Colors.red;
        textColor = Colors.red;
      } else {
        backgroundColor = theme.colorScheme.surfaceContainerHigh;
        borderColor = theme.colorScheme.outline.withAlpha((0.3 * 255).round());
        textColor = theme.colorScheme.onSurface.withAlpha((0.5 * 255).round());
      }
    } else {
      if (isSelected) {
        backgroundColor = theme.colorScheme.primaryContainer;
        borderColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.primary;
      } else {
        backgroundColor = theme.colorScheme.surfaceContainerHigh;
        borderColor = theme.colorScheme.outline.withAlpha((0.3 * 255).round());
        textColor = theme.colorScheme.onSurface.withAlpha((0.7 * 255).round());
      }
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (isCorrect != null && isCorrect!) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, color: Colors.green, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}