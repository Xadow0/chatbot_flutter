import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Controladores para Rive
  SMITrigger? _trigger;
  StateMachineController? _stateMachineController;
  
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _stateMachineController?.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1', // Nombre por defecto, ajusta si es necesario
    );
    
    if (controller != null) {
      artboard.addController(controller);
      _stateMachineController = controller;
      
      // Busca el trigger en la state machine
      _trigger = controller.findInput<bool>('Trigger') as SMITrigger?;
      
      // Si no encuentra 'Trigger', intenta con otros nombres comunes
      _trigger ??= controller.findInput<bool>('trigger') as SMITrigger?;
      _trigger ??= controller.inputs.firstWhere(
        (input) => input is SMITrigger,
        orElse: () => controller.inputs.first,
      ) as SMITrigger?;
    }
  }

  void _onStartPressed() {
    // Muestra la animación y oculta el botón
    setState(() {
      _showAnimation = true;
    });
    
    // Dispara la animación Rive después de un breve delay para asegurar que se renderiza
    Future.delayed(const Duration(milliseconds: 100), () {
      _trigger?.fire();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comenzando la experiencia de aprendizaje...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
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
            
            // Animación Rive en el centro (solo visible cuando _showAnimation es true)
            if (_showAnimation)
              Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: RiveAnimation.asset(
                    'assets/animations/radio_button.riv',
                    fit: BoxFit.contain,
                    onInit: _onRiveInit,
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