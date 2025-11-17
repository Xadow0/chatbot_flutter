import 'package:flutter/material.dart';
import '../../../config/routes.dart';

class StartMenuPage extends StatefulWidget {
  const StartMenuPage({super.key});

  @override
  State<StartMenuPage> createState() => _StartMenuPageState();
}

class _StartMenuPageState extends State<StartMenuPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
  // Quitamos el AppBar
  body: SafeArea(
    child: FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [

                  // ---- TÍTULO CENTRADO VERTICALMENTE ----
                  const SizedBox(height: 40), // Ajusta a tu gusto
                  const Text(
                    'TRAINING.IA',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.lightBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Icono decorativo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black12,
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      size: 80,
                      color: Colors.lightBlue,
                    ),
                  ),

                  const SizedBox(height: 30),
                    
                    Text(
                      'Bienvenido a la estación de entrenamiento IA',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),

                    // Botón Chat Libre
                    _buildMenuButton(
                      context: context,
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat Libre',
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.chat,
                          arguments: {'newConversation': true},
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Botón Aprendizaje
                    _buildMenuButton(
                      context: context,
                      icon: Icons.school_outlined,
                      label: 'Aprendizaje',
                      color: Colors.green,
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.learning);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Botón Historial
                    _buildMenuButton(
                      context: context,
                      icon: Icons.history,
                      label: 'Historial',
                      color: Colors.orange,
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.history);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Botón Ajustes
                    _buildMenuButton(
                      context: context,
                      icon: Icons.settings,
                      label: 'Ajustes',
                      color: Colors.grey,
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.settings);
                      },
                    ),
                    const SizedBox(height: 30),

                    // Botón Créditos
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Créditos próximamente'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: const Text(
                        'Créditos',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}