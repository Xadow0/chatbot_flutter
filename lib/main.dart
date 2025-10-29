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

Future<void> main() async {
  await dotenv.load(fileName: ".env");
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
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // ... (sin cambios) ...
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatbot Demo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.startMenu,
      routes: AppRoutes.routes,
    );
  }
}