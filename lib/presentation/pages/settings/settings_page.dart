// lib/presentation/pages/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../config/routes.dart';
import '../auth/auth_page.dart';

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
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        children: [
          // SECCIÓN: CUENTA Y SINCRONIZACIÓN
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
                
                // SWITCH DE SINCRONIZACIÓN
                SwitchListTile(
                  title: const Text('Guardar conversaciones en la nube'),
                  subtitle: Text(
                    authProvider.isCloudSyncEnabled
                        ? 'Copia de seguridad activa'
                        : 'Solo se guardan localmente',
                  ),
                  secondary: Icon(
                    Icons.cloud_upload,
                    color: authProvider.isCloudSyncEnabled ? Colors.green : Colors.grey,
                  ),
                  value: authProvider.isCloudSyncEnabled,
                  onChanged: authProvider.isSyncing 
                      ? null 
                      : (bool value) {
                          authProvider.toggleCloudSync(value);
                        },
                ),

                // MENSAJE DE ESTADO DE SINCRONIZACIÓN
                if (authProvider.syncMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: authProvider.syncMessage!.contains('✅')
                            ? Colors.green.withOpacity(0.1)
                            : authProvider.syncMessage!.contains('❌')
                                ? Colors.red.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: authProvider.syncMessage!.contains('✅')
                              ? Colors.green
                              : authProvider.syncMessage!.contains('❌')
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (authProvider.isSyncing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              authProvider.syncMessage!.contains('✅')
                                  ? Icons.check_circle
                                  : authProvider.syncMessage!.contains('❌')
                                      ? Icons.error
                                      : Icons.info,
                              size: 20,
                              color: authProvider.syncMessage!.contains('✅')
                                  ? Colors.green
                                  : authProvider.syncMessage!.contains('❌')
                                      ? Colors.red
                                      : Colors.blue,
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authProvider.syncMessage!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // BOTÓN DE SINCRONIZACIÓN MANUAL
                if (authProvider.isCloudSyncEnabled && !authProvider.isSyncing)
                  ListTile(
                    leading: const Icon(Icons.sync, color: Colors.blue),
                    title: const Text('Sincronizar ahora'),
                    subtitle: const Text('Actualizar con la nube manualmente'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await authProvider.manualSync();
                    },
                  ),

                // INFORMACIÓN SOBRE SYNC DESACTIVADO
                if (!authProvider.isCloudSyncEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Con la sincronización desactivada, las conversaciones eliminadas permanecerán en la nube si fueron sincronizadas previamente.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(),

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
                        content: const Text(
                          'Se detendrá la sincronización con la nube. '
                          'Tus conversaciones locales no se eliminarán.',
                        ),
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
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Modo claro';
      case ThemeMode.dark:
        return 'Modo oscuro';
      case ThemeMode.system:
        return 'Automático (sistema)';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
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
              onChanged: (val) {
                if (val != null) {
                  themeProvider.setThemeMode(val);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Modo oscuro'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) {
                  themeProvider.setThemeMode(val);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Automático'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) {
                  themeProvider.setThemeMode(val);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todos los datos?'),
        content: const Text('Esta acción eliminará las conversaciones locales.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datos eliminados')),
              );
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}