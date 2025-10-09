import 'package:flutter/material.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Estado para controlar la visibilidad
  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    
    // Controlador para animación de pulso
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    // Muestra la animación y oculta el botón
    setState(() {
      _showAnimation = true;
    });
    
    // Inicia la animación de pulso
    Future.delayed(const Duration(milliseconds: 100), () {
      _pulseController.repeat(reverse: true);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comenzando la experiencia de aprendizaje...')),
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
            // Botón de inicio en la esquina superior izquierda
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
            
            // Texto animado superior
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
            
            // Animación simple con Flutter (reemplaza la animación Rive)
            if (_showAnimation)
              Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.psychology,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            
            // Botón inferior (solo visible cuando _showAnimation es false)
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
          ],
        ),
      ),
    );
  }
}