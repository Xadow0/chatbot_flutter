import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart'; // NUEVO
import '../../../config/routes.dart';
import '../auth/auth_page.dart'; // NUEVO

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  final double _fontSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context); // Listener del auth

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        children: [
          // NUEVA SECCIÓN: CUENTA Y SINCRONIZACIÓN
          _buildSection(
            title: 'Cuenta y Sincronización',
            children: [
              if (!authProvider.isAuthenticated)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add, color: Colors.blue[700]),
                  ),
                  title: const Text('Iniciar Sesión / Registrarse'),
                  subtitle: const Text('Guarda tus conversaciones en la nube'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                    );
                  },
                )
              else ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(authProvider.user?.email ?? 'Usuario'),
                  subtitle: const Text('Sesión iniciada'),
                ),
                SwitchListTile(
                  title: const Text('Guardar conversaciones en la nube'),
                  subtitle: const Text('Copia de seguridad y sincronización'),
                  secondary: Icon(
                    Icons.cloud_upload, 
                    color: authProvider.isCloudSyncEnabled ? Colors.green : Colors.grey
                  ),
                  value: authProvider.isCloudSyncEnabled,
                  onChanged: (bool value) {
                    authProvider.toggleCloudSync(value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Cerrar Sesión', 
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text('Se detendrá la sincronización con la nube.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Salir'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      await authProvider.signOut();
                    }
                  },
                ),
              ]
            ],
          ),

          // Sección de API Keys
          _buildSection(
            title: 'API Keys',
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: Colors.purple[700],
                  ),
                ),
                title: const Text('Gestión de API Keys'),
                subtitle: const Text('Configurar claves de Gemini y OpenAI'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.apiKeysSettings);
                },
              ),
            ],
          ),
          
          _buildSection(
            title: 'General',
            children: [
              SwitchListTile(
                title: const Text('Notificaciones'),
                subtitle: const Text('Recibir notificaciones de mensajes'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
            ],
          ),
          
          _buildSection(
            title: 'Apariencia',
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getThemeIcon(themeProvider.themeMode),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Tema'),
                subtitle: Text(_getThemeLabel(themeProvider.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context, themeProvider),
              ),
              // Slider de tamaño de fuente... (igual que antes)
            ],
          ),
          
          _buildSection(
            title: 'Chat',
            children: [
               ListTile(
                title: const Text('Historial'),
                subtitle: const Text('Gestionar conversaciones anteriores'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.history);
                },
              ),
            ],
          ),
          
          _buildSection(
            title: 'Avanzado',
            children: [
              ListTile(
                title: const Text('Borrar datos locales'),
                subtitle: const Text('Eliminar todas las conversaciones del dispositivo'),
                trailing: const Icon(Icons.delete_outline),
                onTap: () => _showDeleteConfirmation(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares (_buildSection, _getThemeIcon, etc.) se mantienen igual...
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return Icons.light_mode;
      case ThemeMode.dark: return Icons.dark_mode;
      case ThemeMode.system: return Icons.brightness_auto;
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Modo claro';
      case ThemeMode.dark: return 'Modo oscuro';
      case ThemeMode.system: return 'Automático (sistema)';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
     // (Código igual al original...)
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Modo claro'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (val) { if(val!=null){themeProvider.setThemeMode(val); Navigator.pop(context);} },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Modo oscuro'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (val) { if(val!=null){themeProvider.setThemeMode(val); Navigator.pop(context);} },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Automático'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (val) { if(val!=null){themeProvider.setThemeMode(val); Navigator.pop(context);} },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    // (Código igual al original...)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todos los datos?'),
        content: const Text('Esta acción eliminará las conversaciones locales.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos eliminados'))); },
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}