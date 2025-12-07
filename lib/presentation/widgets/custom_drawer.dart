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
      // Eliminamos el padding por defecto para control total
      child: Column(
        children: [
          // -------------------------------------------
          // 1. CABECERA PERSONALIZADA
          // -------------------------------------------
          _buildCustomHeader(context, authProvider),

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
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.startMenu,
                      (route) => false,
                    );
                  },
                ),
                
                const Divider(),
                
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

                ListTile(
                  leading: const Icon(Icons.school_outlined, color: Colors.green),
                  title: const Text('Aprendizaje'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.learning);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.history, color: Colors.orange),
                  title: const Text('Historial'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.history);
                  },
                ),

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
          // Pequeño espacio de seguridad inferior para móviles modernos sin botones físicos
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // --- WIDGET CABECERA PERSONALIZADA ---
  Widget _buildCustomHeader(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    
    // Obtenemos el padding superior (barra de estado)
    final double paddingTop = MediaQuery.of(context).padding.top;
    
    // Altura total de la cabecera. 
    // Usamos una altura base + el padding del sistema para asegurar que siempre cubra la barra.
    final double headerHeight = 230 + (paddingTop > 24 ? 0 : 0); 

    return Container(
      width: double.infinity,
      height: headerHeight, 
      // Padding ajustado: Top incluye la barra de estado + un extra para respirar
      padding: EdgeInsets.fromLTRB(16, paddingTop + 10, 16, 16),
      decoration: BoxDecoration(
        color: primaryColor,
        image: DecorationImage(
          image: const AssetImage('assets/images/header_bg.png'), 
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            primaryColor.withValues(alpha: 0.8), 
            BlendMode.darken
          ),
          onError: (_, _) {}, 
        ),
      ),
      // Usamos LayoutBuilder para saber exactamente cuánto espacio tenemos dentro
      child: LayoutBuilder(
        builder: (context, constraints) {
          return authProvider.isAuthenticated
              ? _buildAuthenticatedView(context, authProvider, onPrimaryColor, constraints)
              : _buildGuestView(context, onPrimaryColor, constraints);
        },
      ),
    );
  }

  // VISTA: USUARIO LOGUEADO
  Widget _buildAuthenticatedView(BuildContext context, AuthProvider authProvider, Color textColor, BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuye el espacio automáticamente
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LOGO (Top Left)
            _buildAppLogo(),
            
            const Spacer(),
            
            // Switch de Sincronización (Top Right)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end, // Alineado a la derecha
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: authProvider.isCloudSyncEnabled,
                    onChanged: authProvider.isSyncing 
                        ? null 
                        : (val) => authProvider.toggleCloudSync(val),
                    activeThumbColor: const Color.fromARGB(255, 8, 133, 73),
                    activeTrackColor: Colors.white24,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white10,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: authProvider.isCloudSyncEnabled 
                        ? const Color.fromARGB(255, 16, 155, 88).withValues(alpha: 0.2)
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
        
        // Información del usuario (Bottom)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
          children: [
            Text(
              'TRAINING.IA',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            // Flexible evita overflow horizontal si el email es muy largo
            Flexible(
              child: Text(
                authProvider.user?.email ?? 'Usuario',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // VISTA: INVITADO (NO LOGUEADO)
  Widget _buildGuestView(BuildContext context, Color textColor, BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Empuja contenido a los extremos
      children: [
        // LOGO (Top Left)
        _buildAppLogo(),

        // Texto inferior
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TRAINING.IA',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
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
                      color: textColor.withValues(alpha: 0.9),
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
        ),
      ],
    );
  }

  // LOGO CORREGIDO: Tamaño más seguro para móviles (90 en vez de 120)
  Widget _buildAppLogo() {
    return Container(
      width: 90, 
      height: 90,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromARGB(255, 60, 194, 247), 
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover, 
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.psychology, color: Colors.blue, size: 40));
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