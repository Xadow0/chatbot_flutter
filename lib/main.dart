// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/theme_provider.dart';

import 'domain/repositories/chat_repository.dart';
import 'domain/repositories/conversation_repository.dart';
import 'data/services/ai_chat_service.dart';

import 'data/repositories/chat_repository.dart';
import 'data/repositories/conversation_repository.dart';
import 'data/services/api_keys_manager.dart';
import 'data/services/ai_service_selector.dart';
import 'data/services/gemini_service.dart';
import 'data/services/openai_service.dart';
import 'data/services/ollama_service.dart';
import 'data/services/local_ollama_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
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
        // Provider de tema (debe ser el primero para que esté disponible en toda la app)
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        
        ChangeNotifierProvider<AIServiceSelector>.value(
          value: result.aiServiceSelector,
        ),
        
        Provider<AIChatService>(
          create: (context) => AIChatService(
            context.read<AIServiceSelector>(),
          ),
        ),
        
        Provider<ChatRepository>(
          create: (context) => LocalChatRepository(
            context.read<AIChatService>(),
          ),
        ),
        
        Provider<ConversationRepository>(
          create: (_) => ConversationRepositoryImpl(),
        ),
        
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            chatRepository: context.read<ChatRepository>(),
            conversationRepository: context.read<ConversationRepository>(),
            aiServiceSelector: context.read<AIServiceSelector>(),
          ),
        ),
      ],
      child: MyApp(initialRoute: result.initialRoute),
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
    debugPrint('🔍 [Main] No hay API keys guardadas');
    
    await _migrateFromEnvIfAvailable(apiKeysManager);
    
    final hasKeysAfterMigration = await apiKeysManager.hasAnyApiKey();
    
    if (hasKeysAfterMigration) {
      debugPrint('✅ [Main] Keys migradas correctamente → Ir al menú principal');
      return AppRoutes.startMenu;
    } else {
      debugPrint('🔍 [Main] Sin keys → Ir a onboarding');
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