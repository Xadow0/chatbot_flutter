// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/command_management_provider.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

import 'domain/repositories/ichat_repository.dart';
import 'domain/repositories/iconversation_repository.dart';
import 'domain/repositories/icommand_repository.dart'; 

import 'data/services/ai_chat_service.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/conversation_repository.dart';
import 'data/repositories/command_repository.dart'; 

import 'data/services/api_keys_manager.dart';
import 'data/services/ai_service_selector.dart';
import 'data/services/gemini_service.dart';
import 'data/services/openai_service.dart';
import 'data/services/ollama_service.dart';
import 'data/services/local_ollama_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/preferences_service.dart';
import 'data/services/firebase_sync_service.dart';
import 'data/services/firebase_command_sync_service.dart';
import 'data/services/firebase_folder_sync_service.dart';
import 'data/services/secure_storage_service.dart'; 
import 'data/services/local_command_service.dart';
import 'data/services/local_folder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, 
    );
  } catch (e) {
    debugPrint("⚠️ Error inicializando Firebase (o ya inicializado): $e");
  }

  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late Future<_InitializationResult> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatbot Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: FutureBuilder<_InitializationResult>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return _ErrorScreen(error: snapshot.error.toString());
            }
            
            if (snapshot.hasData) {
              final result = snapshot.data!;
              return _buildAppWithProviders(result);
            }
          }
          
          return const _LoadingScreen();
        },
      ),
    );
  }

  Widget _buildAppWithProviders(_InitializationResult result) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        
        Provider<SecureStorageService>(
          create: (_) => SecureStorageService(),
        ),
        Provider<FirebaseSyncService>(
          create: (_) => FirebaseSyncService(),
        ),
        Provider<FirebaseCommandSyncService>(
          create: (_) => FirebaseCommandSyncService(),
        ),
        Provider<FirebaseFolderSyncService>(
          create: (_) => FirebaseFolderSyncService(),
        ),
        Provider<PreferencesService>(
          create: (_) => PreferencesService(),
        ),

        ChangeNotifierProvider<AIServiceSelector>.value(
          value: result.aiServiceSelector,
        ),

        ChangeNotifierProvider(
          create: (context) {
            return AuthProvider(
              authService: AuthService(),
              preferencesService: context.read<PreferencesService>(),
              syncService: context.read<FirebaseSyncService>(),
            );
          },
        ),

        // LocalCommandService
        Provider<LocalCommandService>(
          create: (context) => LocalCommandService(
            context.read<SecureStorageService>(),
          ),
        ),

        // LocalFolderService
        Provider<LocalFolderService>(
          create: (context) => LocalFolderService(
            context.read<SecureStorageService>(),
          ),
        ),
        
        Provider<AIChatService>(
          create: (context) => AIChatService(
            context.read<AIServiceSelector>(),
          ),
        ),

        // CommandRepository con 5 argumentos
        Provider<ICommandRepository>(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            
            return CommandRepositoryImpl(
              context.read<LocalCommandService>(),
              context.read<LocalFolderService>(),
              context.read<FirebaseCommandSyncService>(),
              context.read<FirebaseFolderSyncService>(),
              () => authProvider.isCloudSyncEnabled,
            );
          },
        ),
        
        Provider<IChatRepository>(
          create: (context) => LocalChatRepository(
            context.read<AIChatService>(),
          ),
        ),
        
        Provider<IConversationRepository>(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            
            return ConversationRepositoryImpl(
              syncService: context.read<FirebaseSyncService>(),
              isSyncEnabled: () => authProvider.isCloudSyncEnabled,
            );
          },
        ),

        // CommandManagementProvider
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final commandProvider = CommandManagementProvider(
              context.read<ICommandRepository>() as CommandRepositoryImpl,
            );

            // Vinculación Auth (existente)
            try {
              authProvider.setCommandProvider(commandProvider);
            } catch (e) { debugPrint('Error vinculando auth: $e'); }

            // Listener para cambios de Auth (Login/Logout)
            void authListener() {
               // Si cambia el estado de sync, recargamos
               if (authProvider.isCloudSyncEnabled) {
                 Future.microtask(() => commandProvider.loadCommands(autoSync: true));
               }
            }
            authProvider.addListener(authListener);

            // CARGA INICIAL: Fundamental para que funcione al abrir la app
            Future.microtask(() {
              // Pasamos el estado actual del auth, sea true o false
              commandProvider.loadCommands(
                autoSync: authProvider.isCloudSyncEnabled,
              );
            });

            return commandProvider;
          },
        ),
        
        // ChatProvider - ACTUALIZADO: Vinculación con CommandManagementProvider
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final commandProvider = Provider.of<CommandManagementProvider>(context, listen: false);
            
            final chatProvider = ChatProvider(
              conversationRepository: context.read<IConversationRepository>(),
              commandRepository: context.read<ICommandRepository>(),
              aiServiceSelector: context.read<AIServiceSelector>(),
            );
            
            // Vincular sync status
            chatProvider.setSyncStatusChecker(
              () => authProvider.isCloudSyncEnabled,
            );
            
            // NUEVO: Vincular CommandManagementProvider para obtener carpetas y preferencias
            chatProvider.setCommandManagementProvider(commandProvider);
            
            return chatProvider;
          },
        ),
      ],
      // MODIFICADO: Envolver MyApp con el AppLifecycleManager
      child: _AppLifecycleManager(
        child: MyApp(initialRoute: result.initialRoute),
      ),
    );
  }

  Future<_InitializationResult> _initializeApp() async {
    final initialRoute = await _determineInitialRoute();
    
    final geminiService = GeminiService();
    final openaiService = OpenAIService();
    final ollamaService = OllamaService();
    final localOllamaService = OllamaManagedService();
    
    final aiServiceSelector = AIServiceSelector(
      geminiService: geminiService,
      openaiService: openaiService,
      ollamaService: ollamaService,
      localOllamaService: localOllamaService,
    );
    
    return _InitializationResult(
      initialRoute: initialRoute,
      aiServiceSelector: aiServiceSelector,
    );
  }
}

// ============================================================================
// NUEVO: Widget que gestiona el ciclo de vida de la app a nivel global
// ============================================================================
/// Widget que observa el ciclo de vida de la aplicación y garantiza
/// que las conversaciones se guarden cuando la app se cierra o pasa a segundo plano.
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
    debugPrint('🔄 [AppLifecycleManager] Observer registrado');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('🔄 [AppLifecycleManager] Observer removido');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Intentamos obtener el ChatProvider de forma segura
    final chatProvider = _getChatProviderSafely();
    if (chatProvider == null) {
      debugPrint('⚠️ [AppLifecycleManager] ChatProvider no disponible');
      return;
    }
    
    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('📱 [AppLifecycleManager] App PAUSED - guardando conversación...');
        chatProvider.onAppPaused();
        break;
        
      case AppLifecycleState.detached:
        debugPrint('📱 [AppLifecycleManager] App DETACHED - guardando conversación...');
        chatProvider.onAppDetached();
        break;
        
      case AppLifecycleState.inactive:
        debugPrint('📱 [AppLifecycleManager] App INACTIVE');
        // En algunos dispositivos, inactive precede a paused
        // Guardamos por seguridad
        chatProvider.onAppPaused();
        break;
        
      case AppLifecycleState.resumed:
        debugPrint('📱 [AppLifecycleManager] App RESUMED');
        break;
        
      case AppLifecycleState.hidden:
        debugPrint('📱 [AppLifecycleManager] App HIDDEN - guardando conversación...');
        chatProvider.onAppPaused();
        break;
    }
  }

  /// Obtiene el ChatProvider de forma segura, retornando null si no está disponible
  ChatProvider? _getChatProviderSafely() {
    try {
      return Provider.of<ChatProvider>(context, listen: false);
    } catch (e) {
      debugPrint('⚠️ [AppLifecycleManager] Error obteniendo ChatProvider: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _InitializationResult {
  final String initialRoute;
  final AIServiceSelector aiServiceSelector;

  _InitializationResult({
    required this.initialRoute,
    required this.aiServiceSelector,
  });
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Inicializando...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Error al inicializar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String> _determineInitialRoute() async {
  final apiKeysManager = ApiKeysManager();
  
  final hasKeys = await apiKeysManager.hasAnyApiKey();
  
  if (!hasKeys) {
    debugPrint('🔑 [Main] No hay API keys guardadas');
    
    await _migrateFromEnvIfAvailable(apiKeysManager);
    
    final hasKeysAfterMigration = await apiKeysManager.hasAnyApiKey();
    
    if (hasKeysAfterMigration) {
      debugPrint('✅ [Main] Keys migradas correctamente → Ir al menú principal');
      return AppRoutes.startMenu;
    } else {
      debugPrint('🔑 [Main] Sin keys → Ir a onboarding');
      return AppRoutes.apiKeysOnboarding;
    }
  } else {
    debugPrint('✅ [Main] API keys encontradas en almacenamiento seguro');
    
    await apiKeysManager.printAllKeys();
    
    return AppRoutes.startMenu;
  }
}

Future<void> _migrateFromEnvIfAvailable(ApiKeysManager apiKeysManager) async {
  try {
    final geminiKey = dotenv.env['GEMINI_API_KEY'];
    final openaiKey = dotenv.env['OPENAI_API_KEY'];
    
    bool migrated = false;
    
    if (geminiKey != null && geminiKey.isNotEmpty && geminiKey != '') {
      await apiKeysManager.saveApiKey(
        ApiKeysManager.geminiApiKeyName,
        geminiKey,
      );
      debugPrint('✅ [Main] Gemini API key migrada desde .env');
      migrated = true;
    }
    
    if (openaiKey != null && openaiKey.isNotEmpty && openaiKey != '') {
      await apiKeysManager.saveApiKey(
        ApiKeysManager.openaiApiKeyName,
        openaiKey,
      );
      debugPrint('✅ [Main] OpenAI API key migrada desde .env');
      migrated = true;
    }
    
    if (migrated) {
      debugPrint('✅ [Main] Migración completada. Puedes eliminar las keys del .env');
    } else {
      debugPrint('ℹ️ [Main] No hay keys en .env para migrar');
    }
  } catch (e) {
    debugPrint('❌ [Main] Error en migración desde .env: $e');
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({
    super.key,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Chatbot Demo',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routes: AppRoutes.routes,
          initialRoute: initialRoute,
        );
      },
    );
  }
}