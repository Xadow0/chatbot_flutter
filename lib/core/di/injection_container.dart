// lib/core/di/injection_container.dart
import 'package:get_it/get_it.dart';

// Imports de Core y Services
import '../../core/services/secure_storage_service.dart';
import '../../core/services/conversation_encryption_service.dart'; // NUEVO
import '../../features/settings/data/datasources/preferences_service.dart';
import '../../features/settings/data/datasources/api_keys_manager.dart';
import '../../config/theme/theme_provider.dart';
import '../../shared/widgets/ai_chat_wrapper.dart';

// Imports de Features - Auth
import '../../features/auth/data/datasources/auth_remote_source.dart';
import '../../features/auth/data/datasources/firebase_sync_service.dart';
import '../../features/auth/presentation/logic/auth_provider.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';

// Imports de Features - Commands
import '../../features/commands/data/datasources/local_command_source.dart';
import '../../features/commands/data/datasources/local_folder_source.dart';
import '../../features/commands/data/datasources/firebase_command_sync.dart';
import '../../features/commands/data/datasources/firebase_folder_sync.dart';
import '../../features/commands/data/repositories/command_repository_impl.dart';
import '../../features/commands/domain/repositories/command_repository.dart';
import '../../features/commands/presentation/logic/command_provider.dart';

// Imports de Features - Chat
import '../../features/chat/data/datasources/remote/gemini_datasource.dart';
import '../../features/chat/data/datasources/remote/openai_datasource.dart';
import '../../features/chat/data/datasources/remote/ollama_remote_source.dart';
import '../../features/chat/data/datasources/local/local_ollama_source.dart';
import '../../features/chat/data/utils/ai_service_selector.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/data/repositories/conversation_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/repositories/conversation_repository.dart';
import '../../features/chat/presentation/logic/chat_provider.dart';

final sl = GetIt.instance; // sl = Service Locator

Future<void> init() async {
  // ===========================================================================
  // 1. External & Core Services (Singletons)
  // ===========================================================================
  sl.registerLazySingleton(() => SecureStorageService());
  sl.registerLazySingleton(() => PreferencesService());
  sl.registerLazySingleton(() => ApiKeysManager());
  
  // NUEVO: Servicio de cifrado para conversaciones
  // Depende de SecureStorageService para almacenar el salt de forma segura
  sl.registerLazySingleton(() => ConversationEncryptionService(sl<SecureStorageService>()));

  // ===========================================================================
  // 2. Data Sources (Singletons)
  // ===========================================================================
  
  // Sync Services
  // MODIFICADO: FirebaseSyncService ahora recibe el servicio de cifrado
  sl.registerLazySingleton(() => FirebaseSyncService(sl<ConversationEncryptionService>()));
  sl.registerLazySingleton(() => FirebaseCommandSyncService());
  sl.registerLazySingleton(() => FirebaseFolderSyncService());

  // Local Sources
  sl.registerLazySingleton(() => LocalCommandService(sl())); // Inyecta SecureStorageService automáticamente
  sl.registerLazySingleton(() => LocalFolderService(sl()));
  
  // Auth Source
  sl.registerLazySingleton(() => AuthService());

  // AI Sources
  sl.registerLazySingleton(() => GeminiService());
  sl.registerLazySingleton(() => OpenAIService());
  sl.registerLazySingleton(() => OllamaService());
  sl.registerLazySingleton(() => OllamaManagedService());

  // AI Selector (Logic/Utils)
  sl.registerLazySingleton(() => AIServiceSelector(
    geminiService: sl(),
    openaiService: sl(),
    ollamaService: sl(),
    localOllamaService: sl(),
  ));

  sl.registerLazySingleton(() => AIChatService(sl()));

  // ===========================================================================
  // 3. Repositories (Implementations)
  // ===========================================================================
  
  // Auth Repository
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
    authService: sl(),
    preferencesService: sl(),
    syncService: sl(),
  ));

  // Command Repository
  sl.registerLazySingleton<ICommandRepository>(() => CommandRepositoryImpl(
    sl(), // LocalCommandService
    sl(), // LocalFolderService
    sl(), // FirebaseCommandSync
    sl(), // FirebaseFolderSync
    () => sl<AuthProvider>().isCloudSyncEnabled, // Callback de estado usando el Singleton
  ));

  // Chat Repository
  sl.registerLazySingleton<IChatRepository>(() => LocalChatRepository(
    sl(), // AIChatService
  ));

  // Conversation Repository
  sl.registerLazySingleton<IConversationRepository>(() => ConversationRepositoryImpl(
    syncService: sl(),
    isSyncEnabled: () => sl<AuthProvider>().isCloudSyncEnabled,
  ));

  // ===========================================================================
  // 4. Feature Providers (Presentation Logic)
  // ===========================================================================
  
  // AuthProvider - Singleton porque necesita mantener estado global de sesión
  // Ahora recibe solo el repositorio (Clean Architecture)
  sl.registerLazySingleton(() => AuthProvider(
    authRepository: sl(),
  ));

  // ThemeProvider - Factory porque es independiente y liviano
  sl.registerFactory(() => ThemeProvider());

  // CommandManagementProvider - Factory para instancias frescas
  sl.registerFactory(() => CommandManagementProvider(
    sl<ICommandRepository>() as CommandRepositoryImpl,
  ));

  // ChatProvider - Factory para instancias frescas
  sl.registerFactory(() => ChatProvider(
    conversationRepository: sl(),
    commandRepository: sl(),
    aiServiceSelector: sl(),
  ));
}