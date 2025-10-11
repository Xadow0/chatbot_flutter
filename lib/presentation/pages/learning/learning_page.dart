import 'package:flutter/material.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Controladores para cada elemento del flujo
  late AnimationController _flowController;
  late List<Animation<double>> _elementAnimations;

  bool _showAnimation = false;
  bool _animationComplete = false;

  // Lista de expertos IA
  final List<String> _aiExperts = [
    'IA Experta en\nArquitectura',
    'IA Experta en\nLegislación Española',
    'IA Experta en\nGeneración de Imágenes',
    'IA Experta en\nAnálisis de Datos',
    'IA Experta en\nMedicina',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Controlador principal del flujo (8 elementos: usuario, flecha1, chatbot, flecha2, selector, flecha3, expertos, botón)
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // Crear animaciones para cada elemento con intervalos
    _elementAnimations = List.generate(8, (index) {
      final start = index * 0.12;
      final end = start + 0.15;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _flowController,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
        ),
      );
    });

    _flowController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationComplete = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    setState(() {
      _showAnimation = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _flowController.forward();
    });
  }

  Widget _buildUser() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Usuario (Tú)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildArrow(String label, {bool isVertical = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (isVertical) ...[
          Icon(
            Icons.arrow_upward,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          Container(
            width: 2,
            height: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );
  }

  Widget _buildChatbotInterface() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 32,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            'Interfaz de Chatbot',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            'Selector de Expertos',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExpertBranches() {
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          // Líneas desde el centro hacia cada experto
          Positioned.fill(
            child: CustomPaint(
              painter: _BranchPainter(
                expertCount: _aiExperts.length,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          // Expertos en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _aiExperts.map((expert) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          expert,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Botón de inicio
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.home, size: 32),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/');
                },
                tooltip: 'Volver al menú principal',
              ),
            ),

            // Texto animado superior (oculto cuando comienza la animación)
            if (!_showAnimation)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100.0),
                    child: Text(
                      '¿Cómo funciona la IA generativa?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // Animación del flujo
            if (_showAnimation)
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 6. Ramas a expertos (arriba del todo)
                        FadeTransition(
                          opacity: _elementAnimations[5],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.3),
                              end: Offset.zero,
                            ).animate(_elementAnimations[5]),
                            child: _buildExpertBranches(),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 5. Selector de Expertos
                        FadeTransition(
                          opacity: _elementAnimations[4],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.3),
                              end: Offset.zero,
                            ).animate(_elementAnimations[4]),
                            child: _buildSelector(),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 4. Flecha hacia selector
                        FadeTransition(
                          opacity: _elementAnimations[3],
                          child: _buildArrow(''),
                        ),

                        const SizedBox(height: 8),

                        // 3. Interfaz de Chatbot
                        FadeTransition(
                          opacity: _elementAnimations[2],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.3),
                              end: Offset.zero,
                            ).animate(_elementAnimations[2]),
                            child: _buildChatbotInterface(),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 2. Flecha con "Prompt"
                        FadeTransition(
                          opacity: _elementAnimations[1],
                          child: _buildArrow('Prompt'),
                        ),

                        const SizedBox(height: 8),

                        // 1. Usuario (abajo del todo)
                        FadeTransition(
                          opacity: _elementAnimations[0],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.3),
                              end: Offset.zero,
                            ).animate(_elementAnimations[0]),
                            child: _buildUser(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Botón "Comenzar" (visible solo antes de la animación)
            if (!_showAnimation)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: ElevatedButton(
                    onPressed: _onStartPressed,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Comenzar'),
                  ),
                ),
              ),

            // Botón "Siguiente" (visible solo cuando la animación termina)
            if (_animationComplete)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: FadeTransition(
                    opacity: _elementAnimations[7],
                    child: ElevatedButton(
                      onPressed: () {
                        // Implementar navegación posterior
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidad "Siguiente" pendiente de implementar'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Siguiente'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// CustomPainter para dibujar las líneas desde el selector hacia los expertos
class _BranchPainter extends CustomPainter {
  final int expertCount;
  final Color color;

  _BranchPainter({
    required this.expertCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Punto de inicio (abajo, centro)
    final startPoint = Offset(size.width / 2, size.height);

    // Calcular posiciones de los expertos
    final expertWidth = size.width / expertCount;
    
    for (int i = 0; i < expertCount; i++) {
      // Punto final (arriba, centrado en cada experto)
      final endX = (i + 0.5) * expertWidth;
      final endPoint = Offset(endX, 40);

      // Dibujar línea
      final path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);
      
      // Línea con curva suave
      final controlPoint1 = Offset(startPoint.dx, startPoint.dy - 40);
      final controlPoint2 = Offset(endX, startPoint.dy - 40);
      
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        endPoint.dx, endPoint.dy,
      );
      
      canvas.drawPath(path, paint);

      // Dibujar flecha en el punto final
      _drawArrowHead(canvas, arrowPaint, endPoint, Offset(0, -1));
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset tip, Offset direction) {
    const arrowSize = 8.0;
    final path = Path();
    
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(tip.dx - arrowSize / 2, tip.dy + arrowSize);
    path.lineTo(tip.dx + arrowSize / 2, tip.dy + arrowSize);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}