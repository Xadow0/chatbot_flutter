import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../providers/auth_provider.dart';
import '../pages/auth/auth_page.dart';
import '../pages/commands/user_commands_page.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el proveedor de autenticación
    final authProvider = context.watch<AuthProvider>();
    
    return Drawer(
      // Eliminamos el padding por defecto del Drawer para que la cabecera toque el techo
      child: Column(
        children: [
          // -------------------------------------------
          // 1. CABECERA PERSONALIZADA (SOLUCIONA CORTE Y OVERFLOW)
          // -------------------------------------------
          _buildCustomHeader(context, authProvider),

          // -------------------------------------------
          // 2. LISTA DE NAVEGACIÓN
          // -------------------------------------------
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero, // Importante para pegar la lista a la cabecera
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Menú de inicio'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.startMenu,
                      (route) => false,
                    );
                  },
                ),
                
                const Divider(),
                
                // Opción: CHAT LIBRE
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                  title: const Text('Chat Libre'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context, 
                      AppRoutes.chat,
                      arguments: {'newConversation': true},
                    ); 
                  },
                ),

                // Opción: APRENDIZAJE
                ListTile(
                  leading: const Icon(Icons.school_outlined, color: Colors.green),
                  title: const Text('Aprendizaje'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.learning);
                  },
                ),

                // Opción: HISTORIAL
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text('Historial'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.history);
                  },
                ),

                // Opción: COMANDOS
                ListTile(
                  leading: const Icon(Icons.terminal_rounded, color: Colors.purple),
                  title: const Text('Comandos'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserCommandsPage()),
                    );
                  },
                ),
                
                const Divider(),

                // Opción: AJUSTES
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('Ajustes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.settings);
                  },
                ),
              ],
            ),
          ),

          // -------------------------------------------
          // 3. PIE DE PÁGINA (ACERCA DE)
          // -------------------------------------------
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            onTap: () {
              Navigator.pop(context); 
              _showAboutDialog(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- WIDGET CABECERA PERSONALIZADA ---
  // Usamos Container en lugar de DrawerHeader para tener control total del tamaño y evitar cortes
  Widget _buildCustomHeader(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    
    // Obtenemos el padding superior (barra de estado) para que no se monte
    final double paddingTop = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: 230, // Altura fija suficiente para evitar el OVERFLOW (Error 3)
      padding: EdgeInsets.fromLTRB(16, paddingTop + 16, 16, 16),
      decoration: BoxDecoration(
        color: primaryColor,
        image: DecorationImage(
          image: const AssetImage('assets/images/header_bg.png'), 
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            primaryColor.withOpacity(0.8), 
            BlendMode.darken
          ),
          onError: (_, __) {}, 
        ),
      ),
      child: authProvider.isAuthenticated
          ? _buildAuthenticatedView(context, authProvider, onPrimaryColor)
          : _buildGuestView(context, onPrimaryColor),
    );
  }

  // VISTA: USUARIO LOGUEADO
  Widget _buildAuthenticatedView(BuildContext context, AuthProvider authProvider, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LOGO (Top Left)
            _buildAppLogo(),
            
            const Spacer(),
            
            // Switch de Sincronización (Top Right)
            Column(
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: authProvider.isCloudSyncEnabled,
                    onChanged: authProvider.isSyncing 
                        ? null 
                        : (val) => authProvider.toggleCloudSync(val),
                    activeColor: Colors.greenAccent,
                    activeTrackColor: Colors.white24,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white10,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: authProvider.isCloudSyncEnabled 
                        ? Colors.greenAccent.withOpacity(0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: authProvider.isCloudSyncEnabled 
                          ? Colors.greenAccent 
                          : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    authProvider.isCloudSyncEnabled ? 'Sync ON' : 'Sync OFF',
                    style: TextStyle(
                      color: authProvider.isCloudSyncEnabled ? const Color.fromARGB(255, 0, 112, 58) : const Color.fromARGB(179, 81, 79, 79),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
        const Spacer(),
        Text(
          'TRAINING.IA',
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          authProvider.user?.email ?? 'Usuario',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  // VISTA: INVITADO (NO LOGUEADO)
  Widget _buildGuestView(BuildContext context, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LOGO (Top Left)
        _buildAppLogo(),

        const Spacer(),

        Text(
          'TRAINING.IA',
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bienvenido, Invitado',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Reducimos un poco el espacio aquí para evitar el overflow
        const SizedBox(height: 6), 
        InkWell(
          onTap: () {
             Navigator.pop(context);
             Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Iniciar Sesión',
                style: TextStyle(
                  color: textColor.withOpacity(0.9),
                  decoration: TextDecoration.underline,
                  decorationColor: textColor,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.login, color: textColor, size: 16),
            ],
          ),
        )
      ],
    );
  }

  // CORRECCIÓN LOGO (Punto 1): Ocupa todo el círculo
  Widget _buildAppLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromARGB(255, 60, 194, 247), 
      ),
      // Usamos ClipOval para recortar la imagen en círculo
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          // BoxFit.cover asegura que ocupe TODO el círculo sin bordes blancos internos
          fit: BoxFit.cover, 
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.psychology, color: Colors.blue));
          },
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'TRAINING.IA',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.psychology),
      children: [
        const Text('Plataforma de entrenamiento inteligente y gestión de comandos.'),
      ],
    );
  }
}