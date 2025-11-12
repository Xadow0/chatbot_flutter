// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/chat_provider.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
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
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AIServiceSelector>.value(
          value: aiServiceSelector,
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
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

Future<String> _determineInitialRoute() async {
  final apiKeysManager = ApiKeysManager();
  
  final hasKeys = await apiKeysManager.hasAnyApiKey();
  
  if (!hasKeys) {
    debugPrint('🔒 [Main] No hay API keys guardadas');
    
    await _migrateFromEnvIfAvailable(apiKeysManager);
    
    final hasKeysAfterMigration = await apiKeysManager.hasAnyApiKey();
    
    if (hasKeysAfterMigration) {
      debugPrint('✅ [Main] Keys migradas correctamente → Ir al menú principal');
      return AppRoutes.startMenu;
    } else {
      debugPrint('🔒 [Main] Sin keys → Ir a onboarding');
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
    return MaterialApp(
      title: 'Chatbot Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routes: AppRoutes.routes,
      initialRoute: initialRoute,
    );
  }
}