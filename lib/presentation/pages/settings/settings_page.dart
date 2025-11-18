import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../../config/routes.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  double _fontSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        children: [
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
              ListTile(
                title: const Text('Tamaño de fuente'),
                subtitle: Text('${_fontSize.toStringAsFixed(0)}px'),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: _fontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: _fontSize.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          
          _buildSection(
            title: 'Chat',
            children: [
              ListTile(
                title: const Text('Respuestas rápidas'),
                subtitle: const Text('Configurar respuestas predeterminadas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcionalidad próximamente'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
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
                title: const Text('Borrar datos'),
                subtitle: const Text('Eliminar todas las conversaciones'),
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
              subtitle: const Text('Tema claro siempre activo'),
              secondary: const Icon(Icons.light_mode),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Modo oscuro'),
              subtitle: const Text('Tema oscuro siempre activo'),
              secondary: const Icon(Icons.dark_mode),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Automático'),
              subtitle: const Text('Sigue la configuración del sistema'),
              secondary: const Icon(Icons.brightness_auto),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todos los datos?'),
        content: const Text(
          'Esta acción eliminará todas las conversaciones y no se puede deshacer.',
        ),
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
            child: const Text(
              'Borrar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}