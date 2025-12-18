class AppConstants {
  // App Info
  static const String appName = 'Chatbot Demo';
  static const String appVersion = '1.0.0';
  
  // API Configuration (para futuro)
  static const String baseUrl = 'https://api.example.com';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 16.0;
  static const double messageBubbleMaxWidth = 0.75;
  
  // Chat Settings
  static const int maxMessageLength = 500;
  static const int maxQuickResponses = 5;
  static const Duration botResponseDelay = Duration(milliseconds: 500);
  
  // Storage Keys (para SharedPreferences futuro)
  static const String keyThemeMode = 'theme_mode';
  static const String keyNotifications = 'notifications_enabled';
  static const String keyFontSize = 'font_size';
  static const String keyChatHistory = 'chat_history';
  
  // LLM Local Configuration
  static const String localLLMModelName = 'phi-3-mini';
  static const String localLLMModelDisplayName = 'Phi-3 Mini';
  static const String localLLMModelFile = 'phi-3-mini-4k-instruct-q4.gguf';
  static const String localLLMModelsDirectory = 'models';
  
  // LLM Model Parameters
  static const int localLLMContextSize = 2048;
  static const int localLLMMaxTokens = 512;
  static const double localLLMDefaultTemperature = 0.7;
  static const int localLLMDefaultThreads = 4;
  
  // LLM System Requirements
  static const int localLLMMinRamMB = 2048; // 2GB mínimo recomendado
  static const int localLLMRecommendedRamMB = 4096; // 4GB recomendado
  
  // LLM Download URLs (para futuras implementaciones)
  static const String localLLMDownloadBaseUrl = 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/';
  static const String localLLMDownloadFileName = 'Phi-3-mini-4k-instruct-q4.gguf';
  
  // Timeouts
  static const Duration localLLMLoadTimeout = Duration(seconds: 30);
  static const Duration localLLMInferenceTimeout = Duration(seconds: 60);
  
}

class AppStrings {
  // General
  static const String appTitle = 'Training IA';
  
  // Chat
  static const String chatTitle = 'Chat';
  static const String messageHint = 'Escribe un mensaje...';
  static const String quickResponsesLabel = 'Respuestas rápidas';
  static const String emptyConversation = '¡Empieza una conversación!';
  static const String clearConversation = 'Limpiar conversación';
  
  // Settings
  static const String settingsTitle = 'Ajustes';
  static const String notificationsTitle = 'Notificaciones';
  static const String notificationsSubtitle = 'Recibir notificaciones de mensajes';
  static const String darkModeTitle = 'Modo oscuro';
  static const String darkModeSubtitle = 'Usar tema oscuro';
  
  // Drawer
  static const String aboutTitle = 'Acerca de';
  static const String aboutDescription = 'Una aplicación de chatbot desarrollada con Flutter.';
  
  // LLM Local
  static const String localLLMTitle = 'Modelo Local';
  static const String localLLMDescription = 'IA ejecutándose en tu dispositivo';
  static const String localLLMStarting = 'Iniciando modelo local...';
  static const String localLLMLoading = 'Cargando modelo en memoria...';
  static const String localLLMReady = 'Modelo listo para usar';
  static const String localLLMStopped = 'Modelo detenido';
  static const String localLLMError = 'Error al cargar modelo';
  
  // LLM Local Actions
  static const String localLLMActionStart = 'Iniciar';
  static const String localLLMActionStop = 'Detener';
  static const String localLLMActionRetry = 'Reintentar';
  static const String localLLMActionShowError = 'Ver detalles del error';
  
  // LLM Local Messages
  static const String localLLMMessageStarting = 'Iniciando modelo local...\nEsto puede tardar unos segundos';
  static const String localLLMMessageSuccess = 'Modelo cargado correctamente';
  static const String localLLMMessageStopped = 'Modelo detenido y recursos liberados';
  static const String localLLMMessageNoResources = 'Recursos insuficientes para ejecutar el modelo';
  static const String localLLMMessageModelNotFound = 'Archivo del modelo no encontrado';
  static const String localLLMMessageDownloadRequired = 'Necesitas descargar el modelo primero';
  

}