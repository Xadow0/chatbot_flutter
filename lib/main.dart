// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/chat_provider.dart';

// 1. Importar las INTERFACES (Dominio)
import 'domain/repositories/chat_repository.dart';
import 'domain/repositories/conversation_repository.dart';

// 2. Importar las IMPLEMENTACIONES (Data)
import 'data/repositories/chat_repository.dart';
import 'data/repositories/conversation_repository.dart';

// 🔐 Importar el gestor de API keys
import 'data/services/api_keys_manager.dart';

Future<void> main() async {
  // Asegurar inicialización de Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar .env (opcional, para desarrollo o migración)
  await dotenv.load(fileName: ".env");
  
  // 🔐 Verificar y migrar API keys si es necesario
  final initialRoute = await _determineInitialRoute();
  
  runApp(
    MultiProvider(
      providers: [
        // 3. Proveer las implementaciones concretas
        Provider<ChatRepository>(
          create: (_) => LocalChatRepository(),
        ),
        Provider<ConversationRepository>(
          create: (_) => ConversationRepositoryImpl(),
        ),
        
        // 4. Crear ChatProvider, leyendo las dependencias del contexto
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            // Inyectar las interfaces (Provider encontrará las implementaciones)
            chatRepository: context.read<ChatRepository>(),
            conversationRepository: context.read<ConversationRepository>(),
          ),
        ),
      ],
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

/// 🔐 Determinar la ruta inicial basándose en si hay API keys configuradas
Future<String> _determineInitialRoute() async {
  final apiKeysManager = ApiKeysManager();
  
  // Verificar si ya hay API keys guardadas
  final hasKeys = await apiKeysManager.hasAnyApiKey();
  
  if (!hasKeys) {
    debugPrint('🔑 [Main] No hay API keys guardadas');
    
    // Intentar migración desde .env (solo para desarrollo/primera vez)
    await _migrateFromEnvIfAvailable(apiKeysManager);
    
    // Verificar nuevamente después de la migración
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
    
    // Mostrar estado de las keys (solo en debug)
    await apiKeysManager.printAllKeys();
    
    return AppRoutes.startMenu;
  }
}

/// Migrar API keys desde .env al almacenamiento seguro (solo primera vez)
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