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
        return _ExplanationPage(onNext: _nextPage);
      case 2:
        return _CapabilitiesQuizPage(onNext: _nextPage);
      case 3:
        return _CommunicationPage(onFinish: _completeModule);
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
      'La IA Generativa no busca información ni posee conocimiento propio. '
      'Su función es crear contenido nuevo —como texto, imágenes o sonido— '
      'a partir de los patrones y relaciones que aprendió durante su entrenamiento con grandes cantidades de datos. '
      'En lugar de recordar hechos, predice lo que viene a continuación según el contexto del mensaje que recibe.';
  
  bool _showQuiz = false;
  int? _selectedAnswer;
  bool _answeredCorrectly = false;
  
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
        // Texto completado; mostrar quiz después de un pequeño retraso.
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
  final correctOption = _QuizOption(
    text: 'Predice la mejor respuesta posible',
    isCorrect: true,
  );

  final incorrectOptions = [
    _QuizOption(text: 'Busca en Internet información actualizada', isCorrect: false),
    _QuizOption(text: 'Recuerda tus conversaciones anteriores', isCorrect: false),
    _QuizOption(text: 'Comprende emociones humanas reales', isCorrect: false),
    _QuizOption(text: 'Aprende de lo que le dices en el momento', isCorrect: false),
    _QuizOption(text: 'Decide según lo que considera más justo', isCorrect: false),
    _QuizOption(text: 'Siente empatía por el usuario', isCorrect: false),
    _QuizOption(text: 'Ejecuta comandos directamente en tu dispositivo', isCorrect: false),
    _QuizOption(text: 'Busca una solución exacta a cada problema', isCorrect: false),
  ];

  // Mezclamos 2 incorrectas + la correcta de forma aleatoria
  final random = Random();
  final selectedIncorrect = (incorrectOptions..shuffle(random)).take(2).toList();

  setState(() {
    _quizOptions = [correctOption, ...selectedIncorrect]..shuffle();
  });
}

  void _selectAnswer(int index) {
    setState(() {
      _selectedAnswer = index;
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_quizOptions[index].isCorrect) {
        setState(() {
          _answeredCorrectly = true;
        });
      } else {
        setState(() {
          _selectedAnswer = null;
        });
        _generateQuizOptions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respuesta incorrecta. Inténtalo de nuevo.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Texto animado
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
          
          const SizedBox(height: 40),
          
          // Quiz
          if (_showQuiz) ...[
            Text(
              '¿Qué hace internamente una IA cuando te responde a una petición?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            ..._quizOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _selectedAnswer == index;
              final showCorrect = isSelected && option.isCorrect;
              final showIncorrect = isSelected && !option.isCorrect;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: _selectedAnswer == null ? () => _selectAnswer(index) : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
            color: showCorrect
              ? Colors.green.withAlpha((0.2 * 255).round())
              : showIncorrect
                ? Colors.red.withAlpha((0.2 * 255).round())
                : theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: showCorrect
                            ? Colors.green
                            : showIncorrect
                                ? Colors.red
                                : theme.colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.text,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (showCorrect)
                          const Icon(Icons.check_circle, color: Colors.green),
                        if (showIncorrect)
                          const Icon(Icons.cancel, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          
          const Spacer(),
          
          // Botón siguiente
          if (_answeredCorrectly)
            ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Siguiente'),
            ),
        ],
      ),
    );
  }
}

class _QuizOption {
  final String text;
  final bool isCorrect;

  _QuizOption({required this.text, required this.isCorrect});
}

// ============= PÁGINA DE CAPACIDADES =============
class _CapabilitiesQuizPage extends StatefulWidget {
  final VoidCallback onNext;

  const _CapabilitiesQuizPage({required this.onNext});

  @override
  State<_CapabilitiesQuizPage> createState() => _CapabilitiesQuizPageState();
}

class _CapabilitiesQuizPageState extends State<_CapabilitiesQuizPage> {
  final List<_CapabilityQuestion> _allQuestions = [
    _CapabilityQuestion('Resumir un texto', true),
    _CapabilityQuestion('Comprobar si algo es 100% falso', false),
    _CapabilityQuestion('Juzgar si algo está bien o mal moralmente', false),
    _CapabilityQuestion('Garantizar información correcta', false),
    _CapabilityQuestion('Traducir una frase a otro idioma', true),
    _CapabilityQuestion('Generar un guión', true),
    _CapabilityQuestion('Crear una imagen a partir de una descripción', true),
    _CapabilityQuestion('Dar una opinión personal', false),
  ];

  List<_CapabilityQuestion> _selectedQuestions = [];
  final Map<int, bool?> _userAnswers = {};
  bool _canProceed = false;

  @override
  void initState() {
    super.initState();
    _selectRandomQuestions();
  }

  void _selectRandomQuestions() {
    final random = Random();
    final shuffled = List<_CapabilityQuestion>.from(_allQuestions)..shuffle(random);
    setState(() {
      _selectedQuestions = shuffled.take(4).toList();
    });
  }

  void _answerQuestion(int index, bool answer) {
    setState(() {
      _userAnswers[index] = answer;
      _checkIfCanProceed();
    });
  }

  void _checkIfCanProceed() {
  if (_userAnswers.length == _selectedQuestions.length) {
    bool allCorrect = true;
    for (int i = 0; i < _selectedQuestions.length; i++) {
      if (_userAnswers[i] != _selectedQuestions[i].canDo) {
        allCorrect = false;
        break;
      }
    }

    setState(() {
      _canProceed = allCorrect;
    });

    if (allCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ¡Correcto! Puedes continuar al siguiente módulo.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Algunas respuestas son incorrectas. Revisa tus opciones.'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '¿Qué puede o no puede hacer una IA?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Elige las opciones que una IA pueda hacer:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          Expanded(
            child: ListView.builder(
              itemCount: _selectedQuestions.length,
              itemBuilder: (context, index) {
                final question = _selectedQuestions[index];
                final userAnswer = _userAnswers[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _AnswerButton(
                                label: 'SÍ',
                                isSelected: userAnswer == true,
                                onTap: () => _answerQuestion(index, true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AnswerButton(
                                label: 'NO',
                                isSelected: userAnswer == false,
                                onTap: () => _answerQuestion(index, false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_canProceed)
            ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Siguiente'),
            ),
        ],
      ),
    );
  }
}

class _CapabilityQuestion {
  final String text;
  final bool canDo;

  _CapabilityQuestion(this.text, this.canDo);
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ============= PÁGINA DE COMUNICACIÓN =============
class _CommunicationPage extends StatefulWidget {
  final VoidCallback onFinish;

  const _CommunicationPage({required this.onFinish});

  @override
  State<_CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<_CommunicationPage> {
  String _displayedExplanation = '';
  final String _fullExplanation =
      'Interactuar con una IA es como hablar con alguien muy inteligente pero muy literal. '
      'Sin contexto, puede malinterpretarte. Por eso, la estructura y contenido de tu '
      'prompt cambia completamente su resultado.';
  
  bool _explanationComplete = false;
  
  // Simulación de generación de IA
  final List<String> _targetWords = [
    'La', 'inteligencia', 'artificial', 'genera', 'texto',
    'prediciendo', 'la', 'palabra', 'más', 'probable',
    'en', 'cada', 'momento'
  ];
  
  final List<String> _generatedWords = [];
  String _currentWord = '';
  List<String> _candidateWords = [];
  int _wordIndex = 0;
  bool _isGenerating = false;
  bool _generationComplete = false;

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
        Future.delayed(const Duration(milliseconds: 500), () {
          _startWordGeneration();
        });
      }
    });
  }

  void _startWordGeneration() {
    setState(() {
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

  // Animación más lenta (de 150ms a 250ms)
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
      // Espera un poco más antes de la siguiente palabra
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
                    'Generación en tiempo real:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Texto generado
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
          
          // Botón finalizar
          if (_generationComplete)
            ElevatedButton(
              onPressed: widget.onFinish,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Finalizar Módulo'),
            ),
        ],
      ),
    );
  }
}