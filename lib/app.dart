// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/theme_provider.dart';
import 'core/di/injection_container.dart' as di;

import 'features/auth/presentation/logic/auth_provider.dart';
import 'features/commands/presentation/logic/command_provider.dart';
import 'features/chat/presentation/logic/chat_provider.dart';
import 'features/chat/data/utils/ai_service_selector.dart';

/// Widget principal de la aplicación
/// 
/// Configura:
/// - Inyección de dependencias via Provider
/// - Temas (claro/oscuro)
/// - Rutas de navegación
/// - Gestión de ciclo de vida
class App extends StatelessWidget {
  final String initialRoute;
  
  const App({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Theme Provider
        ChangeNotifierProvider(create: (_) => di.sl<ThemeProvider>()),

        // 2. AI Service Selector (expuesto para cambio de modelos en UI)
        ChangeNotifierProvider.value(value: di.sl<AIServiceSelector>()),

        // 3. Auth Provider (Singleton registrado en GetIt)
        ChangeNotifierProvider.value(value: di.sl<AuthProvider>()),

        // 4. Command Provider
        ChangeNotifierProvider(
          create: (_) {
            final authProvider = di.sl<AuthProvider>();
            final commandProvider = di.sl<CommandManagementProvider>();

            // Vinculación Auth <-> Command
            try {
              authProvider.setCommandProvider(commandProvider);
            } catch (e) {
              debugPrint('Error vinculando auth: $e');
            }

            // Listener para cambios de Auth (Login/Logout)
            void authListener() {
              if (authProvider.isCloudSyncEnabled) {
                Future.microtask(() => commandProvider.loadCommands(autoSync: true));
              }
            }
            authProvider.addListener(authListener);

            // Carga Inicial
            Future.microtask(() {
              commandProvider.loadCommands(
                autoSync: authProvider.isCloudSyncEnabled,
              );
            });

            return commandProvider;
          },
        ),

        // 5. Chat Provider
        ChangeNotifierProvider(
          create: (_) {
            final chatProvider = di.sl<ChatProvider>();
            final authProvider = di.sl<AuthProvider>();
            final commandProvider = di.sl<CommandManagementProvider>();

            // Configuraciones post-inicialización
            chatProvider.setSyncStatusChecker(
              () => authProvider.isCloudSyncEnabled,
            );
            
            chatProvider.setCommandManagementProvider(commandProvider);
            
            return chatProvider;
          },
        ),
      ],
      // Envolvemos con el gestor de ciclo de vida
      child: _AppLifecycleManager(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              title: 'Chatbot Demo',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              routes: AppRoutes.routes,
              initialRoute: initialRoute,
            );
          },
        ),
      ),
    );
  }
}

/// Gestor de ciclo de vida de la aplicación
/// 
/// Se encarga de:
/// - Guardar conversaciones cuando la app pasa a segundo plano
/// - Manejar estados de pausa, detach y hidden
class _AppLifecycleManager extends StatefulWidget {
  final Widget child;
  
  const _AppLifecycleManager({required this.child});

  @override
  State<_AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<_AppLifecycleManager> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      if (state == AppLifecycleState.paused || 
          state == AppLifecycleState.detached || 
          state == AppLifecycleState.hidden) {
        debugPrint('📱 [Lifecycle] App backgrounding - guardando conversación...');
        chatProvider.onAppPaused();
      }
    } catch (e) {
      // Ignorar si el provider no está listo
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}