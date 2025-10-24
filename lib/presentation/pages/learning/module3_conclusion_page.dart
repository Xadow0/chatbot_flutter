import 'package:flutter/material.dart';
import 'dart:async';

class Module3ConclusionPage extends StatefulWidget {
  final VoidCallback onFinish;

  const Module3ConclusionPage({super.key, required this.onFinish});

  @override
  State<Module3ConclusionPage> createState() => _Module3ConclusionPageState();
}

class _Module3ConclusionPageState extends State<Module3ConclusionPage>
    with TickerProviderStateMixin {
  String _displayedMainText = '';
  final String _fullMainText =
      'Ahora ya sabes que la clave no solo está en el prompt... '
      'sino en cómo lo mejoras. ¡Cada mensaje es una oportunidad para afinar el resultado!';

  // Removed unused `_mainTextComplete` - kept animation flow via other flags
  bool _showAnimation = false;
  bool _showWarning = false;
  bool _showButton = false;

  Timer? _textTimer;
  late AnimationController _iterationController;
  late Animation<double> _iterationAnimation;

  // Para la animación de iteración
  final List<_IterationStep> _iterationSteps = [];
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startMainTextAnimation();
  }

  void _initializeAnimations() {
    _iterationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _iterationAnimation = CurvedAnimation(
      parent: _iterationController,
      curve: Curves.easeInOut,
    );

    _iterationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showWarning = true;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _iterationController.dispose();
    super.dispose();
  }

  void _startMainTextAnimation() {
    int charIndex = 0;
    _textTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < _fullMainText.length) {
        setState(() {
          _displayedMainText = _fullMainText.substring(0, charIndex + 1);
        });
        charIndex++;
        } else {
        timer.cancel();
        // main text finished; proceed to show the iteration animation shortly
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showAnimation = true;
            });
            _startIterationAnimation();
          }
        });
      }
    });
  }

  void _startIterationAnimation() {
    // Crear los pasos de iteración
    _iterationSteps.addAll([
      _IterationStep('Prompt inicial', Colors.blue, 0.3),
      _IterationStep('Primera iteración', Colors.green, 0.5),
      _IterationStep('Segunda iteración', Colors.orange, 0.7),
      _IterationStep('Resultado refinado', Colors.purple, 0.9),
    ]);

    _iterationController.forward();

    // Actualizar el paso actual durante la animación
    Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (!mounted || _currentStep >= _iterationSteps.length - 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentStep++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Texto principal animado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
                  theme.colorScheme.secondaryContainer.withAlpha((0.3 * 255).round()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha((0.3 * 255).round()),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _displayedMainText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showAnimation) ...[
            const SizedBox(height: 40),

            // Animación de iteración
            SizedBox(
              height: 300,
              child: AnimatedBuilder(
                animation: _iterationAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _IterationPainter(
                      steps: _iterationSteps,
                      progress: _iterationAnimation.value,
                      currentStep: _currentStep,
                      primaryColor: theme.colorScheme.primary,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _iterationSteps.asMap().entries.map((entry) {
                          final index = entry.key;
                          final step = entry.value;
                          final isActive = index <= _currentStep;
                          final opacity = isActive ? 1.0 : 0.3;

                          return TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            tween: Tween(begin: 0.0, end: opacity),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: step.color.withAlpha((0.2 * 255).round()),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: step.color.withAlpha((value * 255).round()),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isActive ? Icons.check_circle : Icons.circle_outlined,
                                        color: step.color.withAlpha((value * 255).round()),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        step.label,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface.withAlpha((value * 255).round()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          if (_showWarning) ...[
            const SizedBox(height: 32),

            // Advertencia/Consejo
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              onEnd: () {
                setState(() {
                  _showButton = true;
                });
              },
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.error.withAlpha((0.5 * 255).round()),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: theme.colorScheme.error,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '¡Importante!',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Al igual que la iteración sirve para afinar los resultados, '
                          'también puede servir para alejarse de ellos. '
                          'Si ves que la IA cada vez te da un resultado más alejado o menos útil, '
                          'prueba a volver a comenzar en un chat nuevo y a tratar de enfocar '
                          'tu problema desde un enfoque distinto.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          if (_showButton) ...[
            const SizedBox(height: 32),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: ElevatedButton(
                    onPressed: widget.onFinish,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Finalizar Módulo'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _IterationStep {
  final String label;
  final Color color;
  final double position;

  _IterationStep(this.label, this.color, this.position);
}

class _IterationPainter extends CustomPainter {
  final List<_IterationStep> steps;
  final double progress;
  final int currentStep;
  final Color primaryColor;

  _IterationPainter({
    required this.steps,
    required this.progress,
    required this.currentStep,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final arrowPaint = Paint()
      ..style = PaintingStyle.fill;

    // Dibujar líneas conectando los pasos
    for (int i = 0; i < steps.length - 1; i++) {
      final startY = size.height * steps[i].position;
      final endY = size.height * steps[i + 1].position;
      final centerX = size.width / 2;

      // Determinar color y opacidad basado en el progreso
      final stepProgress = (currentStep >= i + 1) ? 1.0 : 0.3;
  paint.color = primaryColor.withAlpha((stepProgress * 255).round());
  arrowPaint.color = primaryColor.withAlpha((stepProgress * 255).round());

      // Dibujar línea curva
      final path = Path();
      path.moveTo(centerX, startY);

      // Curva suave hacia el siguiente paso
      final controlPointX = centerX + 30 * (i % 2 == 0 ? 1 : -1);
      final controlPointY = (startY + endY) / 2;

      path.quadraticBezierTo(
        controlPointX,
        controlPointY,
        centerX,
        endY,
      );

      canvas.drawPath(path, paint);

      // Dibujar flecha en el punto final
      if (stepProgress > 0.5) {
        _drawArrow(canvas, arrowPaint, Offset(centerX, endY), stepProgress);
      }
    }

    // Dibujar puntos en cada paso
    for (int i = 0; i < steps.length; i++) {
      final y = size.height * steps[i].position;
      final centerX = size.width / 2;
      final isActive = i <= currentStep;
  final pointPaint = Paint()
  ..color = steps[i].color.withAlpha(((isActive ? 1.0 : 0.3) * 255).round())
        ..style = PaintingStyle.fill;

      // Punto central
      canvas.drawCircle(
        Offset(centerX, y),
        isActive ? 8 : 6,
        pointPaint,
      );

      // Anillo exterior si está activo
      if (isActive) {
        final ringPaint = Paint()
          ..color = steps[i].color.withAlpha((0.3 * 255).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawCircle(
          Offset(centerX, y),
          12,
          ringPaint,
        );
      }
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset tip, double opacity) {
    final arrowSize = 10.0;
    final path = Path();

    path.moveTo(tip.dx, tip.dy);
    path.lineTo(tip.dx - arrowSize / 2, tip.dy - arrowSize);
    path.lineTo(tip.dx + arrowSize / 2, tip.dy - arrowSize);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IterationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.currentStep != currentStep;
  }
}