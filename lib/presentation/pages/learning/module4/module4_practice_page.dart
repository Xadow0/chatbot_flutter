import 'package:flutter/material.dart';
import 'dart:math' as math;

enum TechniqueType {
  descomposicion,
  metaPreguntas,
  plantillas,
  practica, // Nueva fase: ejercicio práctico
}

class Module4PracticePage extends StatefulWidget {
  final List<TechniqueType> techniqueSequence;
  final VoidCallback onNext;

  const Module4PracticePage({
    super.key,
    required this.techniqueSequence,
    required this.onNext,
  });

  @override
  State<Module4PracticePage> createState() => _Module4PracticePageState();
}

class _Module4PracticePageState extends State<Module4PracticePage> {
  int _currentTechniqueIndex = 0;

  void _nextTechnique() {
    if (_currentTechniqueIndex < widget.techniqueSequence.length - 1) {
      setState(() {
        _currentTechniqueIndex++;
      });
    } else {
      widget.onNext();
    }
  }

  void _previousTechnique() {
    if (_currentTechniqueIndex > 0) {
      setState(() {
        _currentTechniqueIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTechnique = widget.techniqueSequence[_currentTechniqueIndex];
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
            value:
                (_currentTechniqueIndex + 1) / widget.techniqueSequence.length,
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
                'Ejercicio ${_currentTechniqueIndex + 1} de ${widget.techniqueSequence.length}',
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
              // Navegación entre técnicas
              Row(
                children: [
                  if (_currentTechniqueIndex > 0)
                    IconButton(
                      onPressed: _previousTechnique,
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: textColor,
                      ),
                      tooltip: 'Ejercicio anterior',
                    ),
                  if (_currentTechniqueIndex <
                      widget.techniqueSequence.length - 1)
                    IconButton(
                      onPressed: _nextTechnique,
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: textColor,
                      ),
                      tooltip: 'Ejercicio siguiente',
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
              child: _buildTechniqueContent(currentTechnique),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniqueContent(TechniqueType technique) {
    switch (technique) {
      case TechniqueType.descomposicion:
        return AnimatedTechniqueWidget(
          key: const ValueKey('descomposicion'),
          technique: technique,
          onComplete: _nextTechnique,
        );
      case TechniqueType.metaPreguntas:
        return AnimatedTechniqueWidget(
          key: const ValueKey('metaPreguntas'),
          technique: technique,
          onComplete: _nextTechnique,
        );
      case TechniqueType.plantillas:
        return AnimatedTechniqueWidget(
          key: const ValueKey('plantillas'),
          technique: technique,
          onComplete: _nextTechnique,
        );
      case TechniqueType.practica:
        return PracticeExerciseWidget(
          key: const ValueKey('practica'),
          onComplete: _nextTechnique,
        );
    }
  }
}

// ============================================================================
// WIDGET DE ANIMACIÓN DIDÁCTICA
// ============================================================================

class AnimatedTechniqueWidget extends StatefulWidget {
  final TechniqueType technique;
  final VoidCallback onComplete;

  const AnimatedTechniqueWidget({
    super.key,
    required this.technique,
    required this.onComplete,
  });

  @override
  State<AnimatedTechniqueWidget> createState() =>
      _AnimatedTechniqueWidgetState();
}

class _AnimatedTechniqueWidgetState extends State<AnimatedTechniqueWidget>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _contentAnimationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconAnimation;

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

    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _contentAnimationController.forward();
    _startIconAnimation();
  }

  void _startIconAnimation() {
    final steps = _getStepsForTechnique();
    if (steps.isEmpty) return;
    final currentStepData = steps[_currentStep];

    // Diferentes animaciones según el tipo de paso
    if (currentStepData.icon == Icons.close ||
        currentStepData.icon == Icons.error_outline) {
      _iconAnimationController.repeat(reverse: true);
    } else if (currentStepData.icon == Icons.emoji_events ||
        currentStepData.icon == Icons.check_circle) {
      _iconAnimationController.forward();
    } else {
      _iconAnimationController.repeat();
    }
  }

  @override
  void dispose() {
    _contentAnimationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final steps = _getStepsForTechnique();
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

  List<AnimationStep> _getStepsForTechnique() {
    switch (widget.technique) {
      case TechniqueType.descomposicion:
        return _descomposicionSteps;
      case TechniqueType.metaPreguntas:
        return _metaPreguntasSteps;
      case TechniqueType.plantillas:
        return _plantillasSteps;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getStepsForTechnique();
    if (steps.isEmpty) return const SizedBox();
    final currentStepData = steps[_currentStep];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final isLastStep = _currentStep == steps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Text(
          _getTechniqueTitle(),
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
                  color:
                      _getTechniqueColor().withValues(alpha: isDark ? 0.3 : 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Paso ${_currentStep + 1} de ${steps.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? _getTechniqueColor().withValues(alpha: 0.9)
                        : _getTechniqueColor(),
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
          color: _getTechniqueColor(),
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

        // Botón de continuar (solo visible en el último paso)
        if (isLastStep)
          Center(
            child: ElevatedButton.icon(
              onPressed: widget.onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Continuar al siguiente ejercicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getTechniqueColor(),
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

  String _getTechniqueTitle() {
    switch (widget.technique) {
      case TechniqueType.descomposicion:
        return '📋 Caso 1: Planificación y Descomposición';
      case TechniqueType.metaPreguntas:
        return '🧠 Caso 2: Meta-Preguntas';
      case TechniqueType.plantillas:
        return '📝 Caso 3: Plantillas Avanzadas';
      default:
        return '';
    }
  }

  Color _getTechniqueColor() {
    switch (widget.technique) {
      case TechniqueType.descomposicion:
        return Colors.blue;
      case TechniqueType.metaPreguntas:
        return Colors.purple;
      case TechniqueType.plantillas:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStepContent(AnimationStep step, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final exampleBgColor = isDark ? Colors.grey[800] : Colors.grey[100];
    final exampleTextColor = isDark ? Colors.grey[300] : Colors.grey[800];
    final exampleBorderColor = isDark ? Colors.grey[700] : Colors.grey[300];

    return Container(
      key: ValueKey<int>(_currentStep),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono y título del paso con animación
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: step.color.withValues(alpha: isDark ? 0.5 : 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: step.color.withValues(alpha: isDark ? 0.2 : 0.1),
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
                  animation: _iconAnimation,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? step.color.withValues(alpha: 0.9) : step.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contenido del paso
          if (step.description != null) ...[
            Text(
              step.description!,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Ejemplo visual
          if (step.example != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: exampleBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: exampleBorderColor!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        step.exampleIcon ?? Icons.chat_bubble_outline,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        step.exampleLabel ?? 'Ejemplo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.example!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: exampleTextColor,
                    ),
                  ),
                ],
              ),
            ),

          // Resultado/explicación
          if (step.result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(
              result: step.result!,
              color: step.color,
              isDark: isDark,
            ),
          ],
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
      icon:
          isNext ? const SizedBox.shrink() : Icon(icon, size: 18, color: color),
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
                    ? color.withValues(alpha: 0.5)
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
            borderRadius: BorderRadius.circular(5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
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
  final Animation<double> animation;

  const _AnimatedStepIcon({
    required this.icon,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // Diferentes animaciones según el tipo de icono
    if (icon == Icons.close || icon == Icons.error_outline) {
      // Animación de sacudida para errores
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(math.sin(animation.value * 4 * math.pi) * 3, 0),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.emoji_events) {
      // Animación de brillo para victoria
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (math.sin(animation.value * math.pi) * 0.15),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.person) {
      // Animación de balanceo suave
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, math.sin(animation.value * 2 * math.pi) * 2),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.account_tree ||
        icon == Icons.content_paste ||
        icon == Icons.build) {
      // Animación de rotación suave
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: math.sin(animation.value * 2 * math.pi) * 0.1,
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.psychology || icon == Icons.help_outline) {
      // Animación de pulso para pensamiento
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (math.sin(animation.value * 3 * math.pi) * 0.1),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.lightbulb) {
      // Animación de parpadeo para idea
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Opacity(
            opacity: 0.7 + (math.sin(animation.value * 4 * math.pi) * 0.3),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.save || icon == Icons.flash_on) {
      // Animación de escala
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.95 + (animation.value * 0.1),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.settings) {
      // Animación de rotación para configuración
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: animation.value * 2 * math.pi,
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.star) {
      // Animación de brillo para estrella
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.6),
                  color,
                ],
                stops: [
                  0.0,
                  animation.value,
                  1.0,
                ],
              ).createShader(bounds);
            },
            child: Icon(icon, color: Colors.white, size: 32),
          );
        },
      );
    } else if (icon == Icons.description || icon == Icons.edit) {
      // Animación de escritura
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(math.sin(animation.value * 3 * math.pi) * 2, 0),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.folder) {
      // Animación de apertura
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (math.sin(animation.value * math.pi) * 0.08),
            child: Icon(icon, color: color, size: 32),
          );
        },
      );
    } else if (icon == Icons.check_circle) {
      // Animación de confirmación
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (animation.value * 0.2),
            child: Opacity(
              opacity: animation.value,
              child: Icon(icon, color: color, size: 32),
            ),
          );
        },
      );
    }

    // Default: sin animación especial
    return Icon(icon, color: color, size: 32);
  }
}

class _ResultCard extends StatefulWidget {
  final String result;
  final Color color;
  final bool isDark;

  const _ResultCard({
    required this.result,
    required this.color,
    required this.isDark,
  });

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard>
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
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.isDark ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.color.withValues(alpha: widget.isDark ? 0.5 : 0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withValues(alpha: 0.1 + (_glowAnimation.value * 0.1)),
                blurRadius: 8 + (_glowAnimation.value * 8),
                spreadRadius: _glowAnimation.value * 2,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                color: widget.isDark
                    ? widget.color.withValues(alpha: 0.9)
                    : widget.color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.result,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: textColor,
                  ),
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
// MODELOS DE DATOS PARA ANIMACIONES
// ============================================================================

class AnimationStep {
  final String title;
  final String? description;
  final String? example;
  final String? exampleLabel;
  final IconData? exampleIcon;
  final String? result;
  final IconData icon;
  final Color color;

  AnimationStep({
    required this.title,
    this.description,
    this.example,
    this.exampleLabel,
    this.exampleIcon,
    this.result,
    required this.icon,
    required this.color,
  });
}

// ============================================================================
// PASOS DE ANIMACIÓN: DESCOMPOSICIÓN
// ============================================================================

final List<AnimationStep> _descomposicionSteps = [
  AnimationStep(
    title: 'La Situación',
    description:
        'María trabaja en marketing y necesita crear una presentación de 20 diapositivas para proponer un nuevo proyecto. Tiene poco tiempo y no sabe por dónde empezar.',
    icon: Icons.person,
    color: Colors.blue,
  ),
  AnimationStep(
    title: 'El Error Común ❌',
    description: 'María intenta pedirle todo de golpe a la IA:',
    example:
        '"Crea una presentación completa de 20 diapositivas sobre mi proyecto de app móvil. Incluye análisis de mercado, competencia, desarrollo, costos, proyecciones y marketing."',
    exampleLabel: 'Prompt de María',
    exampleIcon: Icons.error_outline,
    result:
        '❌ Resultado: La IA genera contenido genérico y superficial. María tiene que rehacerlo todo.',
    icon: Icons.close,
    color: Colors.red,
  ),
  AnimationStep(
    title: 'La Solución: Paso 1 - Planificar',
    description:
        'María decide usar la técnica de descomposición. Primero, pide ayuda para planificar:',
    example:
        '"Ayúdame a estructurar una presentación de negocio para una app móvil de productividad. Dame: 1) Secciones principales, 2) Diapositivas por sección, 3) Puntos clave de cada una."',
    exampleLabel: 'Planificación',
    exampleIcon: Icons.lightbulb,
    result:
        '✅ La IA le devuelve un plan detallado con 5 secciones y 20 diapositivas distribuidas lógicamente.',
    icon: Icons.account_tree,
    color: Colors.blue,
  ),
  AnimationStep(
    title: 'La Solución: Paso 2 - Ejecutar por Partes',
    description: 'Ahora María genera cada sección por separado:',
    example:
        '"Genera el contenido para la Sección 1: Análisis de Mercado (diapositivas 1-5). Incluye: tamaño del mercado, tendencias actuales, oportunidad identificada y datos relevantes."',
    exampleLabel: 'Primera sección',
    exampleIcon: Icons.edit,
    result:
        '✅ Contenido detallado, específico y bien fundamentado para las primeras 5 diapositivas.',
    icon: Icons.content_paste,
    color: Colors.blue,
  ),
  AnimationStep(
    title: 'El Resultado Final 🎯',
    description:
        'María continúa el proceso con cada sección. Después de 5 prompts específicos, tiene una presentación profesional y completa.',
    example:
        '• Sección 1: Análisis de Mercado ✓\n• Sección 2: Competencia ✓\n• Sección 3: Propuesta de Valor ✓\n• Sección 4: Plan de Desarrollo ✓\n• Sección 5: Proyecciones Financieras ✓',
    exampleLabel: 'Presentación completa',
    exampleIcon: Icons.check_circle,
    result:
        '🎉 María ahorró 3 horas de trabajo y obtuvo contenido de calidad profesional. La clave: dividir la tarea compleja en pasos manejables.',
    icon: Icons.emoji_events,
    color: Colors.green,
  ),
];

// ============================================================================
// PASOS DE ANIMACIÓN: META-PREGUNTAS
// ============================================================================

final List<AnimationStep> _metaPreguntasSteps = [
  AnimationStep(
    title: 'La Situación',
    description:
        'Carlos tiene una tienda online y necesita escribir 50 descripciones de productos. Quiere que sean consistentes y atractivas, pero no sabe cómo estructurar el prompt perfecto.',
    icon: Icons.person,
    color: Colors.purple,
  ),
  AnimationStep(
    title: 'El Error Común ❌',
    description: 'Carlos escribe prompts vagos cada vez:',
    example:
        '"Escribe una descripción de producto para esta camiseta."\n\n[Resultado: Texto genérico]\n\n"Ahora para estos zapatos."\n\n[Resultado: Estilo completamente diferente]\n\n"Para este gorro."\n\n[Resultado: Otra vez diferente]',
    exampleLabel: 'Enfoque inconsistente',
    exampleIcon: Icons.error_outline,
    result:
        '❌ Problema: Cada descripción es diferente. Pierde tiempo ajustando cada una. No hay consistencia en su catálogo.',
    icon: Icons.close,
    color: Colors.red,
  ),
  AnimationStep(
    title: 'La Solución: Hacer Meta-Preguntas',
    description:
        'Carlos decide crear un prompt reutilizable. Primero pregunta:',
    example:
        '"Quiero crear un prompt que genere descripciones de productos para mi tienda de ropa deportiva. ¿Qué información necesitas de mí para ayudarme a construir ese prompt perfecto?"',
    exampleLabel: 'Meta-pregunta',
    exampleIcon: Icons.psychology,
    result:
        '✅ La IA responde con una lista de preguntas clave que Carlos debe responder.',
    icon: Icons.help_outline,
    color: Colors.purple,
  ),
  AnimationStep(
    title: 'La Construcción del Prompt',
    description: 'La IA le pregunta y Carlos responde:',
    example:
        'IA: "¿Longitud? ¿Tono? ¿Estructura? ¿Call-to-action?"\n\nCarlos responde:\n• 150-200 palabras\n• Tono inspirador y profesional\n• Beneficios + uso recomendado\n• Sí, incluir CTA motivador\n• Párrafos cortos, fácil de leer',
    exampleLabel: 'Definiendo parámetros',
    exampleIcon: Icons.settings,
    result:
        '✅ La IA tiene toda la información necesaria para crear el prompt ideal.',
    icon: Icons.build,
    color: Colors.purple,
  ),
  AnimationStep(
    title: 'El Prompt Perfecto 🎯',
    description: 'La IA genera el prompt final:',
    example:
        '"Escribe una descripción de producto deportivo entre 150-200 palabras. Tono inspirador y profesional. Estructura: 1) Introducción atractiva, 2) 3 beneficios principales, 3) Uso recomendado, 4) CTA motivador. Párrafos cortos.\n\nProducto: [NOMBRE DEL PRODUCTO]"',
    exampleLabel: 'Prompt reutilizable',
    exampleIcon: Icons.star,
    result:
        '🎉 Carlos ahora tiene un prompt que puede usar para todos sus productos. Solo cambia el nombre y obtiene descripciones consistentes y profesionales. ¡Ahorra horas de trabajo!',
    icon: Icons.emoji_events,
    color: Colors.green,
  ),
];

// ============================================================================
// PASOS DE ANIMACIÓN: PLANTILLAS
// ============================================================================

final List<AnimationStep> _plantillasSteps = [
  AnimationStep(
    title: 'La Situación',
    description:
        'Laura es project manager y cada día escribe muchos emails: solicitudes, seguimientos, respuestas... Pierde mucho tiempo pensando cómo redactar cada uno.',
    icon: Icons.person,
    color: Colors.green,
  ),
  AnimationStep(
    title: 'El Error Común ❌',
    description: 'Laura escribe cada email desde cero:',
    example:
        '[Lunes 9:00] "Ayúdame a escribir un email para pedir una reunión"\n\n[Lunes 11:30] "Necesito un email de seguimiento de proyecto"\n\n[Martes 10:00] "Cómo respondo a esta solicitud formal"\n\n[Martes 15:00] "Email para solicitar más recursos"',
    exampleLabel: 'Sin sistema',
    exampleIcon: Icons.error_outline,
    result:
        '❌ Problema: Cada vez tiene que explicar el contexto desde cero. Pierde 15-20 minutos por email. El formato es inconsistente.',
    icon: Icons.close,
    color: Colors.red,
  ),
  AnimationStep(
    title: 'La Solución: Crear Plantillas',
    description:
        'Laura decide crear plantillas reutilizables para sus emails más frecuentes:',
    example:
        '📧 Plantilla 1: Email de Solicitud\n"Escribe un email profesional de solicitud:\n• Destinatario: [nombre/cargo]\n• Solicitud: [qué pido]\n• Contexto: [por qué]\n• Urgencia: [alta/media/baja]\n• Tono: [formal/cordial]"',
    exampleLabel: 'Plantilla de solicitud',
    exampleIcon: Icons.description,
    result: '✅ Laura guarda esta plantilla en un documento.',
    icon: Icons.save,
    color: Colors.green,
  ),
  AnimationStep(
    title: 'Uso de la Plantilla',
    description: 'Cuando necesita escribir un email de solicitud:',
    example:
        '"Escribe un email profesional de solicitud:\n• Destinatario: Director de IT\n• Solicitud: Acceso a servidor de pruebas\n• Contexto: Necesario para testing del nuevo módulo\n• Urgencia: alta\n• Tono: formal pero cordial"',
    exampleLabel: 'Plantilla completada',
    exampleIcon: Icons.edit,
    result:
        '✅ En 30 segundos tiene un email perfecto. Solo tuvo que rellenar los campos.',
    icon: Icons.flash_on,
    color: Colors.green,
  ),
  AnimationStep(
    title: 'Su Biblioteca de Plantillas 🎯',
    description:
        'Laura crea plantillas para todas sus necesidades frecuentes:',
    example:
        '📚 Biblioteca de Laura:\n\n✉️ Email de Solicitud\n✉️ Email de Seguimiento\n✉️ Email de Actualización\n✉️ Email de Respuesta Formal\n📊 Resumen Ejecutivo\n📋 Informe de Estado\n✍️ Notas de Reunión',
    exampleLabel: 'Kit de plantillas',
    exampleIcon: Icons.folder,
    result:
        '🎉 Laura ahora escribe emails en 2 minutos en vez de 15. Ahorró 2 horas diarias y sus comunicaciones son más profesionales y consistentes.',
    icon: Icons.emoji_events,
    color: Colors.green,
  ),
];

// ============================================================================
// WIDGET DE EJERCICIO PRÁCTICO
// ============================================================================

class PracticeExerciseWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const PracticeExerciseWidget({
    super.key,
    required this.onComplete,
  });

  @override
  State<PracticeExerciseWidget> createState() => _PracticeExerciseWidgetState();
}

class _PracticeExerciseWidgetState extends State<PracticeExerciseWidget> {
  bool _showInstructions = true;

  @override
  Widget build(BuildContext context) {
    if (_showInstructions) {
      return _buildInstructions();
    } else {
      return _buildPracticeChat();
    }
  }

  Widget _buildInstructions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBgColor = isDark ? Colors.grey[850] : Colors.white;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Ejercicio Práctico Final',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                  Colors.purple.withValues(alpha: isDark ? 0.2 : 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withValues(alpha: isDark ? 0.5 : 0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu Misión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Imagina que eres responsable de crear contenido para el blog de tu empresa. Necesitas escribir 3 artículos sobre inteligencia artificial.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Debes aplicar las 3 técnicas aprendidas:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1️⃣ Descomposición: Planifica la estructura de tus 3 artículos\n\n'
                  '2️⃣ Meta-preguntas: Crea el prompt perfecto para escribir artículos de blog\n\n'
                  '3️⃣ Plantillas: Genera el primer artículo usando tu plantilla',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: isDark ? 0.5 : 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDark ? Colors.amber[400] : Colors.amber[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guía de Pasos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber[400] : Colors.amber[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paso 1: Pide a la IA que te ayude a planificar los 3 artículos\n\n'
                        'Paso 2: Pregunta qué información necesita para crear un prompt perfecto de artículo de blog\n\n'
                        'Paso 3: Usa ese prompt para generar el primer artículo',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Navegar a la página de chat
                Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {'newConversation': true},
                ).then((_) {
                  // Cuando regrese del chat, volver a mostrar instrucciones
                  if (mounted) {
                    setState(() {
                      _showInstructions = true;
                    });
                  }
                });
              },
              icon: const Icon(Icons.chat),
              label: const Text('Abrir Chat de Práctica'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: widget.onComplete,
              child: Text(
                'Saltar ejercicio y continuar',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeChat() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBgColor = isDark ? Colors.grey[850] : Colors.grey[100];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con explicación compacta
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withValues(alpha: isDark ? 0.5 : 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.school,
                color: isDark ? Colors.blue[400] : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aplica las 3 técnicas en una conversación real',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.help_outline,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _showInstructions = true;
                  });
                },
                tooltip: 'Ver instrucciones',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mensaje de inicio del ejercicio
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Chat de Práctica',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aquí podrás conversar con la IA y aplicar\nlas técnicas que has aprendido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botones de acción
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showInstructions = true;
                  });
                },
                icon: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                label: Text(
                  'Ver Guía',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onComplete,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Finalizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}