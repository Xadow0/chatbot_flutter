import 'package:flutter/material.dart';
import 'dart:math' as math;

enum EthicsScenarioType {
  sesgos,
  decisiones,
  responsabilidad,
}

class Module5EthicsScenariosPage extends StatefulWidget {
  final List<EthicsScenarioType> scenarioSequence;
  final VoidCallback onNext;

  const Module5EthicsScenariosPage({
    super.key,
    required this.scenarioSequence,
    required this.onNext,
  });

  @override
  State<Module5EthicsScenariosPage> createState() =>
      _Module5EthicsScenariosPageState();
}

class _Module5EthicsScenariosPageState
    extends State<Module5EthicsScenariosPage> {
  int _currentScenarioIndex = 0;

  void _nextScenario() {
    if (_currentScenarioIndex < widget.scenarioSequence.length - 1) {
      setState(() {
        _currentScenarioIndex++;
      });
    } else {
      widget.onNext();
    }
  }

  void _previousScenario() {
    if (_currentScenarioIndex > 0) {
      setState(() {
        _currentScenarioIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentScenario = widget.scenarioSequence[_currentScenarioIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador de progreso
          LinearProgressIndicator(
            value: (_currentScenarioIndex + 1) / widget.scenarioSequence.length,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.blue[400]! : Colors.blue,
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Caso ${_currentScenarioIndex + 1} de ${widget.scenarioSequence.length}',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
              // Navegación entre escenarios
              Row(
                children: [
                  if (_currentScenarioIndex > 0)
                    IconButton(
                      onPressed: _previousScenario,
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: textColor,
                      ),
                      tooltip: 'Caso anterior',
                    ),
                  if (_currentScenarioIndex < widget.scenarioSequence.length - 1)
                    IconButton(
                      onPressed: _nextScenario,
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: textColor,
                      ),
                      tooltip: 'Caso siguiente',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: AnimatedEthicsScenarioWidget(
                key: ValueKey(currentScenario),
                scenario: currentScenario,
                onComplete: _nextScenario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET DE ANIMACIÓN DE ESCENARIOS ÉTICOS
// ============================================================================

class AnimatedEthicsScenarioWidget extends StatefulWidget {
  final EthicsScenarioType scenario;
  final VoidCallback onComplete;

  const AnimatedEthicsScenarioWidget({
    super.key,
    required this.scenario,
    required this.onComplete,
  });

  @override
  State<AnimatedEthicsScenarioWidget> createState() =>
      _AnimatedEthicsScenarioWidgetState();
}

class _AnimatedEthicsScenarioWidgetState
    extends State<AnimatedEthicsScenarioWidget>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _contentAnimationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconRotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _contentAnimationController.forward();
    _startIconAnimation();
  }

  void _startIconAnimation() {
    final steps = _getStepsForScenario();
    final currentStepData = steps[_currentStep];

    // Diferentes animaciones según el tipo de paso
    if (currentStepData.icon == Icons.warning ||
        currentStepData.icon == Icons.warning_amber ||
        currentStepData.icon == Icons.error_outline) {
      _iconAnimationController.repeat(reverse: true);
    } else if (currentStepData.icon == Icons.search ||
        currentStepData.icon == Icons.computer) {
      _iconAnimationController.repeat();
    } else {
      _iconAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _contentAnimationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final steps = _getStepsForScenario();
    if (_currentStep < steps.length - 1) {
      _contentAnimationController.reset();
      _iconAnimationController.reset();
      setState(() {
        _currentStep++;
      });
      _contentAnimationController.forward();
      _startIconAnimation();
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      _contentAnimationController.reset();
      _iconAnimationController.reset();
      setState(() {
        _currentStep--;
      });
      _contentAnimationController.forward();
      _startIconAnimation();
    }
  }

  List<EthicsStep> _getStepsForScenario() {
    switch (widget.scenario) {
      case EthicsScenarioType.sesgos:
        return _sesgosSteps;
      case EthicsScenarioType.decisiones:
        return _decisionesSteps;
      case EthicsScenarioType.responsabilidad:
        return _responsabilidadSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getStepsForScenario();
    final currentStepData = steps[_currentStep];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final isLastStep = _currentStep == steps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título del escenario
        Text(
          _getScenarioTitle(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),

        // Controles de navegación de pasos
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón anterior
              _NavigationButton(
                icon: Icons.arrow_back_rounded,
                label: 'Anterior',
                onPressed: _currentStep > 0 ? _goToPreviousStep : null,
                isDark: isDark,
              ),

              // Indicador de paso
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getScenarioColor().withOpacity(isDark ? 0.3 : 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Paso ${_currentStep + 1} de ${steps.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? _getScenarioColor().withOpacity(0.9)
                        : _getScenarioColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Botón siguiente
              _NavigationButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Siguiente',
                onPressed: !isLastStep ? _goToNextStep : null,
                isDark: isDark,
                isNext: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progreso visual con puntos
        _StepProgressIndicator(
          totalSteps: steps.length,
          currentStep: _currentStep,
          color: _getScenarioColor(),
          isDark: isDark,
        ),

        const SizedBox(height: 24),

        // Contenido animado
        Expanded(
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildStepContent(currentStepData, isDark),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botón continuar al siguiente escenario
        if (isLastStep)
          Center(
            child: ElevatedButton.icon(
              onPressed: widget.onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Continuar al siguiente caso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getScenarioColor(),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getScenarioTitle() {
    switch (widget.scenario) {
      case EthicsScenarioType.sesgos:
        return '🔍 Caso Real: Sesgos en la IA';
      case EthicsScenarioType.decisiones:
        return '⚕️ Caso Real: Decisiones Importantes';
      case EthicsScenarioType.responsabilidad:
        return '⚖️ Caso Real: Responsabilidad Personal';
    }
  }

  Color _getScenarioColor() {
    switch (widget.scenario) {
      case EthicsScenarioType.sesgos:
        return Colors.red;
      case EthicsScenarioType.decisiones:
        return Colors.orange;
      case EthicsScenarioType.responsabilidad:
        return Colors.purple;
    }
  }

  Widget _buildStepContent(EthicsStep step, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final detailsBgColor = isDark ? Colors.grey[800] : Colors.grey[100];
    final detailsTextColor = isDark ? Colors.grey[300] : Colors.grey[800];

    return Container(
      key: ValueKey<int>(_currentStep),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del paso con animación
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: step.color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: step.color.withOpacity(isDark ? 0.5 : 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: step.color.withOpacity(isDark ? 0.2 : 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icono animado
                _AnimatedStepIcon(
                  icon: step.icon,
                  color: step.color,
                  animationController: _iconAnimationController,
                  animation: _iconRotationAnimation,
                  stepType: step.icon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? step.color.withOpacity(0.9)
                          : step.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Contenido principal
          if (step.content != null)
            Text(
              step.content!,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: textColor,
              ),
            ),

          if (step.content != null && step.details != null)
            const SizedBox(height: 16),

          // Detalles adicionales
          if (step.details != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: detailsBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                step.details!,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: detailsTextColor,
                ),
              ),
            ),

          if (step.lesson != null) const SizedBox(height: 20),

          // Lección aprendida
          if (step.lesson != null)
            _LessonCard(
              step: step,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDark;
  final bool isNext;

  const _NavigationButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.isDark,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final color = isEnabled
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.grey[700] : Colors.grey[400]);

    return TextButton.icon(
      onPressed: onPressed,
      icon: isNext ? const SizedBox.shrink() : Icon(icon, size: 18, color: color),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: color),
          ],
        ],
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _StepProgressIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Color color;
  final bool isDark;

  const _StepProgressIndicator({
    required this.totalSteps,
    required this.currentStep,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        final isPast = index < currentStep;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? color
                : isPast
                    ? color.withOpacity(0.5)
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
            borderRadius: BorderRadius.circular(5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _AnimatedStepIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AnimationController animationController;
  final Animation<double> animation;
  final IconData stepType;

  const _AnimatedStepIcon({
    required this.icon,
    required this.color,
    required this.animationController,
    required this.animation,
    required this.stepType,
  });

  @override
  Widget build(BuildContext context) {
    // Diferentes animaciones según el tipo de icono
    if (icon == Icons.warning || icon == Icons.warning_amber) {
      // Animación de pulso para advertencias
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (animation.value * 0.15),
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.search) {
      // Animación de rotación para búsqueda
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: math.sin(animation.value * 2 * math.pi) * 0.1,
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.computer) {
      // Animación de parpadeo para computadora
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Opacity(
            opacity: 0.7 + (math.sin(animation.value * 4 * math.pi) * 0.3),
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.gavel) {
      // Animación de golpe para martillo
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: math.sin(animation.value * math.pi) * -0.3,
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.trending_up) {
      // Animación de subida
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -math.sin(animation.value * math.pi) * 5),
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.school) {
      // Animación de brillo para lección
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.6),
                  color,
                ],
                stops: [
                  0.0,
                  animation.value,
                  1.0,
                ],
              ).createShader(bounds);
            },
            child: Icon(icon, color: Colors.white, size: 40),
          );
        },
      );
    } else if (icon == Icons.emergency || icon == Icons.error_outline) {
      // Animación de alerta
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (math.sin(animation.value * 4 * math.pi) * 0.1),
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.local_hospital) {
      // Animación de latido para hospital
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final scale = 1.0 + (math.sin(animation.value * 2 * math.pi) * 0.1);
          return Transform.scale(
            scale: scale,
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.person || icon == Icons.person_outline) {
      // Animación sutil de balanceo
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(math.sin(animation.value * 2 * math.pi) * 3, 0),
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    } else if (icon == Icons.business) {
      // Sin animación especial, solo fade in
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Opacity(
            opacity: 0.8 + (animation.value * 0.2),
            child: Icon(icon, color: color, size: 40),
          );
        },
      );
    }

    // Default: sin animación especial
    return Icon(icon, color: color, size: 40);
  }
}

class _LessonCard extends StatefulWidget {
  final EthicsStep step;
  final bool isDark;

  const _LessonCard({
    required this.step,
    required this.isDark,
  });

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonColor = widget.step.lessonColor ?? Colors.green;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: lessonColor.withOpacity(widget.isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: lessonColor.withOpacity(widget.isDark ? 0.5 : 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: lessonColor
                    .withOpacity(0.1 + (_glowAnimation.value * 0.15)),
                blurRadius: 10 + (_glowAnimation.value * 10),
                spreadRadius: _glowAnimation.value * 2,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.step.lessonIcon ?? Icons.school,
                color: widget.isDark
                    ? lessonColor.withOpacity(0.9)
                    : lessonColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.step.lessonTitle ?? 'Lección',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark
                            ? lessonColor.withOpacity(0.9)
                            : lessonColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.step.lesson!,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// MODELO DE DATOS PARA PASOS ÉTICOS
// ============================================================================

class EthicsStep {
  final String title;
  final String? content;
  final String? details;
  final String? lesson;
  final String? lessonTitle;
  final IconData? lessonIcon;
  final Color? lessonColor;
  final IconData icon;
  final Color color;

  EthicsStep({
    required this.title,
    this.content,
    this.details,
    this.lesson,
    this.lessonTitle,
    this.lessonIcon,
    this.lessonColor,
    required this.icon,
    required this.color,
  });
}

// ============================================================================
// ESCENARIO 1: SESGOS EN LA IA
// ============================================================================

final List<EthicsStep> _sesgosSteps = [
  EthicsStep(
    title: 'La Situación',
    content:
        'TechCorp es una empresa tecnológica que decidió usar IA para automatizar su proceso de selección de personal. Querían ahorrar tiempo y ser "más objetivos".',
    details:
        'Desarrollaron un sistema que analizaba CVs y asignaba puntuaciones a los candidatos. Los CVs mejor puntuados pasaban a entrevista.',
    icon: Icons.business,
    color: Colors.red,
  ),
  EthicsStep(
    title: 'El Problema Oculto',
    content:
        'Después de 6 meses, una empleada de recursos humanos notó algo extraño: casi ninguna mujer llegaba a la fase de entrevistas.',
    details:
        'Al investigar, descubrieron que la IA había sido entrenada con los CVs de los últimos 10 años de la empresa. En ese periodo, el 85% de las contrataciones habían sido hombres, especialmente en puestos técnicos.\n\n'
        'La IA "aprendió" que:\n'
        '• Palabras como "fútbol" o "videojuegos" en hobbies = Buena señal\n'
        '• CVs de universidades femeninas = Penalización\n'
        '• Experiencia en empresas tech lideradas por hombres = Bonus\n'
        '• Pausas laborales (maternidad) = Penalización severa',
    icon: Icons.search,
    color: Colors.red,
  ),
  EthicsStep(
    title: 'Las Consecuencias',
    content:
        'Durante esos 6 meses, cientos de mujeres altamente cualificadas fueron rechazadas automáticamente. Muchas ni siquiera sabían que una IA había tomado la decisión.',
    details:
        'Consecuencias reales:\n'
        '• Candidatas cualificadas perdieron oportunidades\n'
        '• La empresa perdió talento valioso\n'
        '• Reforzaron la desigualdad de género en tech\n'
        '• Enfrentaron una demanda colectiva\n'
        '• Daño reputacional masivo',
    icon: Icons.gavel,
    color: Colors.red,
  ),
  EthicsStep(
    title: '¿Qué Salió Mal?',
    content:
        'La IA no fue "malvada" ni "decidió discriminar". Simplemente aprendió los patrones históricos de la empresa, que ya eran discriminatorios.',
    details:
        'Los sesgos humanos del pasado se convirtieron en sesgos algorítmicos del presente.\n\n'
        'Esto es EXACTAMENTE lo que pasa cuando:\n'
        '• Entrenas IA con datos históricos sesgados\n'
        '• Asumes que "objetivo = justo"\n'
        '• Delegas decisiones importantes sin supervisión\n'
        '• No cuestionas los resultados de la IA',
    icon: Icons.error_outline,
    color: Colors.red,
  ),
  EthicsStep(
    title: 'La Lección',
    lesson:
        'La IA NO es neutral. Reproduce y amplifica los sesgos que existen en sus datos de entrenamiento.\n\n'
        'Si la sociedad tiene prejuicios (y los tiene), la IA entrenada con datos de esa sociedad también los tendrá.\n\n'
        'Tu responsabilidad:\n'
        '• Cuestiona SIEMPRE las respuestas de la IA\n'
        '• Busca señales de sesgo (racial, género, edad, etc.)\n'
        '• No asumas objetividad automática\n'
        '• Contrasta con fuentes diversas\n'
        '• Nunca uses IA para decisiones que afecten a personas sin supervisión humana crítica',
    lessonTitle: '⚠️ Conclusión: Los Sesgos Son Reales',
    lessonIcon: Icons.warning_amber,
    lessonColor: Colors.orange,
    icon: Icons.school,
    color: Colors.red,
  ),
];

// ============================================================================
// ESCENARIO 2: DECISIONES IMPORTANTES
// ============================================================================

final List<EthicsStep> _decisionesSteps = [
  EthicsStep(
    title: 'La Situación',
    content:
        'Miguel es un médico de atención primaria con 20 años de experiencia. Un día, descubre una IA médica que promete diagnosticar enfermedades analizando síntomas.',
    details:
        'La IA parece increíble: responde en segundos, parece segura de sí misma, cita estudios médicos. Miguel comienza a usarla como "segunda opinión".',
    icon: Icons.local_hospital,
    color: Colors.orange,
  ),
  EthicsStep(
    title: 'El Caso de Ana',
    content:
        'Ana, 34 años, llega a consulta con: fatiga extrema, pérdida de peso, mareos ocasionales. Miguel introduce los síntomas en la IA.',
    details:
        'La IA responde con confianza:\n'
        '"Probable diagnóstico: Anemia por deficiencia de hierro. Tratamiento recomendado: Suplementos de hierro, dieta rica en hierro, seguimiento en 3 meses."\n\n'
        'Miguel, cansado después de un día largo, confía en la IA. Prescribe hierro y agenda seguimiento.',
    icon: Icons.person,
    color: Colors.orange,
  ),
  EthicsStep(
    title: 'La Realidad',
    content:
        'Tres semanas después, Ana regresa. Está peor: más débil, dolor abdominal, ictericia (piel amarillenta).',
    details:
        'Miguel realiza exámenes completos. El diagnóstico real: Cáncer de páncreas en etapa temprana.\n\n'
        'Los síntomas iniciales eran compatibles con anemia, pero también eran señales de alerta tempranas de algo más grave.\n\n'
        'La IA solo buscó el diagnóstico "más común" para esos síntomas. No consideró:\n'
        '• El historial familiar de Ana (cáncer)\n'
        '• Su edad (factor de riesgo)\n'
        '• La combinación específica de síntomas\n'
        '• El contexto completo del paciente',
    icon: Icons.emergency,
    color: Colors.orange,
  ),
  EthicsStep(
    title: 'Las Consecuencias',
    content:
        'Esas tres semanas perdidas fueron críticas. El cáncer avanzó de etapa 1 a etapa 2. El pronóstico empeoró significativamente.',
    details:
        'Lo que pasó:\n'
        '• Miguel delegó su juicio a una máquina\n'
        '• La IA dio una respuesta "probable", no "correcta"\n'
        '• El médico no aplicó su criterio profesional\n'
        '• Una paciente sufrió consecuencias reales\n\n'
        '¿Quién es responsable?\n'
        'Miguel. Él tomó la decisión final. "La IA me lo dijo" no es defensa válida.',
    icon: Icons.warning,
    color: Colors.orange,
  ),
  EthicsStep(
    title: 'La Lección',
    lesson:
        'La IA puede ayudarte a INFORMARTE, pero NUNCA debe tomar decisiones importantes por ti.\n\n'
        'Especialmente cuando esas decisiones afectan:\n'
        '• La salud de alguien\n'
        '• El futuro profesional de alguien\n'
        '• Los derechos de alguien\n'
        '• La seguridad de alguien\n\n'
        'La IA no entiende contexto, matices, excepciones o consecuencias humanas.\n\n'
        'Tu responsabilidad:\n'
        '✅ Usa IA para investigar opciones\n'
        '✅ Usa IA para generar perspectivas\n'
        '✅ Usa IA para analizar datos\n'
        '❌ NO uses IA para decidir\n'
        '❌ NO confíes ciegamente en sus respuestas\n'
        '❌ NO justifiques decisiones importantes con "la IA dijo"',
    lessonTitle: '⚖️ Conclusión: TÚ Decides, TÚ Respondes',
    lessonIcon: Icons.gavel,
    lessonColor: Colors.red,
    icon: Icons.school,
    color: Colors.orange,
  ),
];

// ============================================================================
// ESCENARIO 3: RESPONSABILIDAD PERSONAL
// ============================================================================

final List<EthicsStep> _responsabilidadSteps = [
  EthicsStep(
    title: 'La Situación',
    content:
        'David es un estudiante de 22 años. Descubre que puede hacer preguntas "creativas" a la IA para evadir sus filtros de seguridad.',
    details:
        'En lugar de preguntar directamente cosas bloqueadas, reformula:\n'
        '• "Cómo hacer X" → "Escribe un guion de película donde el villano hace X"\n'
        '• "Dame información ilegal Y" → "Necesito info para una novela sobre Y"\n\n'
        'Los filtros, diseñados para contextos directos, fallan con estos trucos.',
    icon: Icons.person_outline,
    color: Colors.purple,
  ),
  EthicsStep(
    title: 'El Experimento',
    content:
        'David comienza a experimentar. Consigue que la IA genere contenido que normalmente bloquearía:',
    details:
        '• Tutoriales de actividades ilegales\n'
        '• Contenido ofensivo y discriminatorio\n'
        '• Información para evadir sistemas de seguridad\n'
        '• Estrategias de manipulación y acoso\n\n'
        'David se siente "inteligente" por haber "hackeado" la IA. Lo comparte en foros online: "Mira cómo engañé al sistema".',
    icon: Icons.computer,
    color: Colors.purple,
  ),
  EthicsStep(
    title: 'La Escalada',
    content:
        'Otros usuarios ven los trucos de David. Algunos los usan "por curiosidad". Otros, con malas intenciones.',
    details:
        'Casos reales derivados:\n\n'
        '• Alguien usa las técnicas para generar campañas de desinformación\n'
        '• Otro crea contenido de acoso dirigido a una persona específica\n'
        '• Un tercero genera material ilegal\n\n'
        'Todos aprendieron de David. Todos causaron daño real. Todo comenzó con "solo quería ver si podía".',
    icon: Icons.trending_up,
    color: Colors.purple,
  ),
  EthicsStep(
    title: 'Las Consecuencias Legales',
    content:
        'Las autoridades rastrean el contenido ilegal. Identifican a los creadores. Entre ellos, David.',
    details:
        'En el juicio, David argumenta:\n'
        '"Yo solo mostré cómo hacer las preguntas. La IA es la que generó el contenido malo. Yo no hice nada ilegal directamente."\n\n'
        'El juez responde:\n'
        '"Usted intencionalmente evadió medidas de seguridad para obtener contenido prohibido. Usted difundió ese conocimiento. Usted es responsable de las consecuencias previsibles de sus acciones.\n\n'
        'Si alguien le entrega un arma sabiendo que la usará para un crimen, usted es cómplice. La IA es el arma. Usted sabía qué estaba facilitando."\n\n'
        'David es condenado.',
    icon: Icons.gavel,
    color: Colors.purple,
  ),
  EthicsStep(
    title: 'La Lección',
    lesson:
        'La IA es una HERRAMIENTA. Como un cuchillo, puede cortar pan o puede herir.\n\n'
        'La responsabilidad NO está en la herramienta. Está en quien la usa.\n\n'
        '🔧 Analogía del martillo:\n'
        'Si usas un martillo para construir una casa → Eres constructor\n'
        'Si usas un martillo para romper un cráneo → Eres criminal\n\n'
        'El martillo no es bueno ni malo. TU INTENCIÓN y TUS ACCIONES definen la consecuencia.\n\n'
        '🤖 Lo mismo con la IA:\n'
        '• Si generas contenido ilegal → TÚ eres responsable\n'
        '• Si creas desinformación → TÚ eres responsable\n'
        '• Si acosas a alguien → TÚ eres responsable\n'
        '• Si evades filtros de seguridad intencionalmente → TÚ eres responsable\n\n'
        '"La IA lo hizo" NO es defensa legal.\n'
        '"Solo quería ver si podía" NO es excusa.\n'
        '"Fue un experimento" NO te exime.\n\n'
        'La ley es clara: El usuario responde por el uso que hace de la herramienta.',
    lessonTitle: '⚖️ Conclusión: Sin Excusas',
    lessonIcon: Icons.balance,
    lessonColor: Colors.red,
    icon: Icons.school,
    color: Colors.purple,
  ),
];