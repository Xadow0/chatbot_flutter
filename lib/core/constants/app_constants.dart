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
}

class AppStrings {
  // General
  static const String appTitle = 'Chatbot Demo';
  
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
}