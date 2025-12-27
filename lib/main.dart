// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'config/routes.dart';
import 'firebase_options.dart';
import 'core/di/injection_container.dart' as di;
import 'features/settings/data/datasources/api_keys_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");
  
  // Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, 
    );
  } catch (e) {
    debugPrint("⚠️ Error inicializando Firebase: $e");
  }

  // INYECCIÓN DE DEPENDENCIAS
  await di.init();

  // Determinar ruta inicial
  final initialRoute = await _determineInitialRoute();

  runApp(App(initialRoute: initialRoute));
}

/// Determina la ruta inicial basándose en si el usuario tiene API keys configuradas
Future<String> _determineInitialRoute() async {
  final apiKeysManager = di.sl<ApiKeysManager>();
  
  final hasKeys = await apiKeysManager.hasAnyApiKey();
  
  if (!hasKeys) {
    await _migrateFromEnvIfAvailable(apiKeysManager);
    if (await apiKeysManager.hasAnyApiKey()) {
      return AppRoutes.startMenu;
    } else {
      return AppRoutes.apiKeysOnboarding;
    }
  }
  return AppRoutes.startMenu;
}

/// Migra API keys desde el archivo .env si están disponibles
Future<void> _migrateFromEnvIfAvailable(ApiKeysManager apiKeysManager) async {
  try {
    final geminiKey = dotenv.env['GEMINI_API_KEY'];
    final openaiKey = dotenv.env['OPENAI_API_KEY'];
    
    if (geminiKey != null && geminiKey.isNotEmpty) {
      await apiKeysManager.saveApiKey(ApiKeysManager.geminiApiKeyName, geminiKey);
      debugPrint('✅ Migrada API key de Gemini desde .env');
    }
    
    if (openaiKey != null && openaiKey.isNotEmpty) {
      await apiKeysManager.saveApiKey(ApiKeysManager.openaiApiKeyName, openaiKey);
      debugPrint('✅ Migrada API key de OpenAI desde .env');
    }
  } catch (e) {
    debugPrint('❌ Error migración .env: $e');
  }
}