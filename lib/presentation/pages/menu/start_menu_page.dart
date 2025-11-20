import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../auth/auth_page.dart';

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
      body: SafeArea(
        child: Stack(
          children: [
            // -------------------------------------------
            // CAPA 1: CONTENIDO PRINCIPAL
            // -------------------------------------------
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              children: [
                                // 1. AUMENTO ESPACIO SUPERIOR
                                // Subimos de 30 a 85 para librar totalmente el Header de sesión
                                const SizedBox(height: 85), 
                                
                                // TÍTULO
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
                                
                                // 2. COMPACTACIÓN DE ESPACIOS INTERMEDIOS
                                // Reducimos espacios y tamaños para compensar la bajada del título
                                // y que los botones no se muevan de su sitio original.
                                const SizedBox(height: 10), // Antes 20

                                // ICONO PRINCIPAL (Más compacto)
                                Container(
                                  padding: const EdgeInsets.all(16), // Antes 20
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black12,
                                  ),
                                  child: const Icon(
                                    Icons.psychology_outlined,
                                    size: 60, // Antes 70 (y mucho antes 80)
                                    color: Colors.lightBlue,
                                  ),
                                ),

                                const SizedBox(height: 10), // Antes 20

                                Text(
                                  'Bienvenido a la estación de entrenamiento IA',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                // ESPACIO FLEXIBLE
                                // Absorbe cualquier pequeña diferencia restante
                                const Spacer(), 

                                // --- BOTONES DEL MENÚ ---
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

                                _buildMenuButton(
                                  context: context,
                                  icon: Icons.settings,
                                  label: 'Ajustes',
                                  color: Colors.grey,
                                  onPressed: () {
                                    Navigator.pushNamed(context, AppRoutes.settings);
                                  },
                                ),
                                
                                const Spacer(), 

                                // CRÉDITOS
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
                                
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // -------------------------------------------
            // CAPA 2: HEADER DE SESIÓN (SIN CAMBIOS)
            // -------------------------------------------
            Positioned(
              top: 12,
              left: 16,
              right: 16, 
              child: _buildAuthHeader(context),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HEADER DE AUTENTICACIÓN ---
  Widget _buildAuthHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colores base de alta visibilidad
    final backgroundColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1);
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final primaryColor = theme.colorScheme.primary; // Usamos el color primario del sistema actual

    // 1. ESTADO: NO AUTENTICADO
    if (!authProvider.isAuthenticated) {
      return Align(
        alignment: Alignment.centerLeft, // Alineamos a la izquierda
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor, // Usamos el mismo fondo visible que el estado conectado
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: primaryColor.withOpacity(0.5), // Borde coloreado para destacar acción
                  width: 1.5
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Se ajusta al contenido
                children: [
                  Icon(
                    Icons.login_rounded, 
                    size: 20, 
                    color: primaryColor
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 2. ESTADO: AUTENTICADO
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: primaryColor,
            child: Text(
              authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 14, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Información de usuario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sesión iniciada como:',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                Text(
                  authProvider.user?.email ?? 'Usuario',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Switch de Sincronización
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Switch(
                  value: authProvider.isCloudSyncEnabled,
                  onChanged: authProvider.isSyncing 
                    ? null 
                    : (val) => authProvider.toggleCloudSync(val),
                  activeThumbColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                authProvider.isCloudSyncEnabled ? 'Sync ON' : 'Sync OFF',
                style: TextStyle(
                  fontSize: 8,
                  color: authProvider.isCloudSyncEnabled ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA LOS BOTONES DEL MENÚ PRINCIPAL ---
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