import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../config/routes.dart';
import '../auth/auth_page.dart';
import '../../widgets/custom_drawer.dart';

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

    return Scaffold(
      // Añadimos el Drawer aquí para reemplazar el botón de "Atrás"
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

  void _showDeleteAccountDialog(BuildContext context, AuthProvider authProvider) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Eliminar cuenta'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Esta acción es PERMANENTE e IRREVERSIBLE',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  const Text('Se eliminarán:'),
                  const SizedBox(height: 8),
                  _buildDeleteItem('Todas tus conversaciones en la nube'),
                  _buildDeleteItem('Todos tus comandos personalizados'),
                  _buildDeleteItem('Tu cuenta y datos de autenticación'),
                  const SizedBox(height: 16),
                  const Text(
                    'Ingresa tu contraseña para confirmar:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No podrás recuperar tu cuenta después de eliminarla',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                if (!formKey.currentState!.validate()) return;

                final password = passwordController.text;
                
                // Cerrar diálogo de confirmación PRIMERO
                Navigator.pop(dialogContext);
                
                // Pequeño delay para que el diálogo se cierre completamente
                await Future.delayed(const Duration(milliseconds: 100));
                
                // AHORA sí hacer dispose (después de cerrar el diálogo)
                passwordController.dispose();
                
                // Verificar que el contexto siga montado
                if (!context.mounted) return;
                
                // ============================================================
                // FIX PRINCIPAL: Usar una variable para controlar el diálogo
                // ============================================================
                //ignore: unused_local_variable
                BuildContext? loadingDialogContext;
                
                // Mostrar diálogo de carga
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) {
                    // Guardamos referencia al contexto del diálogo
                    loadingDialogContext = ctx;
                    return PopScope(
                      canPop: false,  // Reemplaza WillPopScope deprecado
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
                                const CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
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
                
                // Ejecutar eliminación
                await authProvider.deleteAccount(password);
                
                // ============================================================
                // FIX: Cerrar el diálogo usando Navigator.of(context).pop()
                // Esto es más seguro que usar el contexto guardado
                // ============================================================
                if (context.mounted) {
                  // Usar Navigator.of con rootNavigator para asegurar que cerramos el diálogo correcto
                  Navigator.of(context, rootNavigator: true).pop();
                }
                
                // Pequeño delay para que el diálogo se cierre
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Verificar resultado
                if (!context.mounted) return;
                
                if (authProvider.errorMessage != null) {
                  // Error
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
                  // Éxito
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
                  
                  // Pequeño delay y navegar
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