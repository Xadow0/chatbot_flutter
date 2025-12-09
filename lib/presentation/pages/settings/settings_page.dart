import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../config/routes.dart';
import '../auth/auth_page.dart';
import '../../widgets/custom_drawer.dart';
import '../../pages/dialogs/ollama_setup_dialog.dart';
import '../../../../data/models/local_ollama_models.dart';
import 'local_models_management_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  // ignore: unused_field
  final double _fontSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      drawer: const CustomDrawer(),
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
                            ? Colors.green.withValues(alpha: 0.1)
                            : authProvider.syncMessage!.contains('❌')
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
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
                        color: Colors.orange.withValues(alpha: 0.1),
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
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await authProvider.signOut();
                    }
                  },
                ),

                // OPCIÓN DE ELIMINAR CUENTA
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Eliminar cuenta',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('Esta acción es permanente e irreversible'),
                  onTap: () => _showDeleteAccountDialog(context, authProvider),
                ),
              ],
            ],
          ),

          _buildSection(
            title: 'Integraciones',
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

          // NUEVA SECCIÓN: IA LOCAL
          _buildLocalAISection(context, chatProvider),

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

  /// Sección de IA Local con gestión de modelos
  Widget _buildLocalAISection(BuildContext context, ChatProvider chatProvider) {
    final localService = chatProvider.aiSelector.localOllamaService;
    final isPlatformSupported = localService.isPlatformSupported;
    final status = chatProvider.localOllamaStatus;
    final isReady = status == LocalOllamaStatus.ready;
    final isProcessing = status.isProcessing;
    final modelsCount = localService.availableModels.length;

    return _buildSection(
      title: 'IA Local (Ollama)',
      children: [
        // Info de estado con botón de activar/reintentar
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.computer,
              color: _getStatusColor(status),
            ),
          ),
          title: const Text('Estado del servicio'),
          subtitle: Text(
            isPlatformSupported
                ? status.displayText
                : 'No disponible en esta plataforma',
          ),
          trailing: _buildServiceActionButton(
            context, 
            chatProvider, 
            isPlatformSupported, 
            status, 
            isReady, 
            isProcessing,
          ),
        ),

        // Gestión de modelos (solo si está soportado)
        if (isPlatformSupported)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.storage,
                color: Colors.teal[700],
              ),
            ),
            title: const Text('Gestionar modelos descargados'),
            subtitle: Text(
              isReady
                  ? '$modelsCount modelo${modelsCount != 1 ? 's' : ''} instalado${modelsCount != 1 ? 's' : ''}'
                  : 'Inicia Ollama Local para gestionar',
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: isReady,
            onTap: isReady
                ? () async {
                    // Navegar y esperar resultado
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocalModelsManagementPage(),
                      ),
                    );
                    // Al volver, refrescar los modelos para actualizar el contador
                    if (mounted && chatProvider.localOllamaStatus == LocalOllamaStatus.ready) {
                      await chatProvider.aiSelector.localOllamaService.refreshModels();
                      // Forzar rebuild del widget
                      setState(() {});
                    }
                  }
                : null,
          ),

        // Info adicional si no está listo (y no está procesando)
        if (isPlatformSupported && !isReady && !isProcessing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Activa Ollama Local para usar IA de forma privada sin conexión a internet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Construye el botón de acción del servicio según el estado
  Widget _buildServiceActionButton(
    BuildContext context,
    ChatProvider chatProvider,
    bool isPlatformSupported,
    LocalOllamaStatus status,
    bool isReady,
    bool isProcessing,
  ) {
    // Si no está soportado, mostrar solo el indicador
    if (!isPlatformSupported) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _getStatusColor(status),
          shape: BoxShape.circle,
        ),
      );
    }

    // Si está procesando, mostrar indicador de carga
    if (isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Si está listo, mostrar indicador verde
    if (isReady) {
      return Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      );
    }

    // Si no está inicializado o hay error, mostrar botón de activar
    return FilledButton.tonal(
      onPressed: () => _startLocalOllama(context, chatProvider),
      child: Text(
        status == LocalOllamaStatus.error ? 'Reintentar' : 'Activar',
      ),
    );
  }

  /// Inicia el servicio de Ollama Local mostrando el diálogo de configuración
  Future<void> _startLocalOllama(BuildContext context, ChatProvider chatProvider) async {
    // Importar el diálogo de setup
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OllamaSetupDialog(
        localOllamaService: chatProvider.aiSelector.localOllamaService,
      ),
    );

    if (result == true && mounted) {
      // Verificar que el estado sea ready
      if (chatProvider.localOllamaStatus == LocalOllamaStatus.ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Ollama Local activado correctamente'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Actualizar UI
        setState(() {});
      }
    }
  }

  Color _getStatusColor(LocalOllamaStatus status) {
    switch (status) {
      case LocalOllamaStatus.ready:
        return Colors.green;
      case LocalOllamaStatus.error:
        return Colors.red;
      case LocalOllamaStatus.notInitialized:
        return Colors.grey;
      default:
        return Colors.orange;
    }
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
              title: const Text('Automático (sistema)'),
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
        content: const Text(
          'Se eliminarán todas las conversaciones guardadas en este dispositivo. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implementar borrado de datos locales
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Datos locales eliminados'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider authProvider) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text('Eliminar cuenta'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Esta acción es PERMANENTE e IRREVERSIBLE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Se eliminarán:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildDeleteItem('Tu cuenta de usuario'),
              _buildDeleteItem('Todas tus conversaciones en la nube'),
              _buildDeleteItem('Tus preferencias y configuraciones'),
              _buildDeleteItem('Acceso a todos tus datos'),
              const SizedBox(height: 16),
              const Text(
                'Para confirmar, ingresa tu contraseña:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Contraseña actual',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              passwordController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa tu contraseña para continuar'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);
              await Future.delayed(const Duration(milliseconds: 100));
              passwordController.dispose();
              if (!context.mounted) return;

              // ignore: unused_local_variable
              BuildContext? loadingDialogContext;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  loadingDialogContext = ctx;
                  return PopScope(
                    canPop: false,
                    child: Center(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 3),
                              const SizedBox(height: 24),
                              const Text(
                                'Eliminando cuenta',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Por favor espera...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.hourglass_empty,
                                      size: 16,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Esto puede tomar unos segundos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );

              await authProvider.deleteAccount(password);

              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              await Future.delayed(const Duration(milliseconds: 100));

              if (!context.mounted) return;

              if (authProvider.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(authProvider.errorMessage!),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                authProvider.clearError();
              } else if (!authProvider.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ Cuenta eliminada exitosamente'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                await Future.delayed(const Duration(milliseconds: 300));

                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Eliminar cuenta permanentemente'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, size: 14, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}