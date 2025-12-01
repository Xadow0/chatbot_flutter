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
    final theme = Theme.of(context);
    
    return Drawer(
      child: Column(
        children: [
          // -------------------------------------------
          // 1. CABECERA (ADAPTADA A ESTADO DE SESIÓN)
          // -------------------------------------------
          _buildDrawerHeader(context, authProvider),

          // -------------------------------------------
          // 2. LISTA DE NAVEGACIÓN
          // -------------------------------------------
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Menú de inicio'),
                  onTap: () {
                    Navigator.pop(context);
                    // Usamos pushNamedAndRemoveUntil para volver al inicio limpio
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.startMenu,
                      (route) => false,
                    );
                  },
                ),
                
                const Divider(),
                
                // Opción: CHAT LIBRE (Color Azul - Consistencia UI)
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                  title: const Text('Chat Libre'),
                  onTap: () {
                    Navigator.pop(context);
                    // Si ya estamos en chat, reemplazamos, si no, push
                    Navigator.pushNamed(context, AppRoutes.chat); 
                  },
                ),

                // Opción: APRENDIZAJE (Color Verde - Agregado)
                ListTile(
                  leading: const Icon(Icons.school_outlined, color: Colors.green),
                  title: const Text('Aprendizaje'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.learning);
                  },
                ),

                // Opción: HISTORIAL (Color Naranja)
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text('Historial'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.history);
                  },
                ),

                // Opción: COMANDOS (Color Morado - Agregado)
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

                // Opción: AJUSTES (Color Gris)
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
              // Cerramos drawer antes de mostrar diálogo
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
  Widget _buildDrawerHeader(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;

    return DrawerHeader(
      decoration: BoxDecoration(
        color: primaryColor,
        image: DecorationImage(
          image: const AssetImage('assets/images/header_bg.png'), // Opcional: si tienes una imagen de fondo
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            primaryColor.withOpacity(0.8), 
            BlendMode.darken
          ),
          onError: (_, __) {}, // Evita error si no existe la imagen
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Text(
                authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const Spacer(),
            // Switch de Sincronización (Compacto)
            Column(
              children: [
                Transform.scale(
                  scale: 0.8, // Hacemos el switch un poco más pequeño para el drawer
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
                Text(
                  authProvider.isCloudSyncEnabled ? 'Sync ON' : 'Sync OFF',
                  style: TextStyle(
                    color: authProvider.isCloudSyncEnabled ? Colors.greenAccent : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          Icons.psychology_outlined,
          size: 48,
          color: textColor,
        ),
        const SizedBox(height: 12),
        Text(
          'Bienvenido, Invitado',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
             Navigator.pop(context); // Cerrar drawer
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