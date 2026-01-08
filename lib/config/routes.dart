import 'package:flutter/material.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/menu/presentation/pages/start_menu_page.dart';
import '../features/chat/presentation/pages/history_page.dart';
import '../features/learning/presentation/pages/learning_page.dart';
import '../features/learning/presentation/pages/module1/module1_page.dart';
import '../features/learning/presentation/pages/module2/module2_page.dart';
import '../features/learning/presentation/pages/module3/module3_page.dart';
import '../features/learning/presentation/pages/module4/module4_page.dart';
import '../features/learning/presentation/pages/module5/module5_page.dart';
import '../features/commands/presentation/pages/user_commands_page.dart'; 

import '../features/settings/presentation/onboarding/api_keys_onboarding_page.dart';
import '../features/settings/presentation/pages/api_keys_settings_page.dart';

class AppRoutes {
  static const String startMenu = '/';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String history = '/history';
  static const String learning = '/learning';
  static const String learningModule1 = '/learning/module1';
  static const String learningModule2 = '/learning/module2';
  static const String learningModule3 = '/learning/module3';
  static const String learningModule4 = '/learning/module4';
  static const String learningModule5 = '/learning/module5';
  static const String commands = '/commands';

  static const String apiKeysOnboarding = '/api-keys-onboarding';
  static const String apiKeysSettings = '/api-keys-settings';

  static Map<String, WidgetBuilder> get routes {
    return {
      startMenu: (context) => const StartMenuPage(),
      chat: (context) => const ChatPage(),
      settings: (context) => const SettingsPage(),
      history: (context) => const HistoryPage(),
      learning: (context) => const LearningPage(),
      learningModule1: (context) => const Module1Page(),
      learningModule2: (context) => const Module2Page(),
      learningModule3: (context) => const Module3Page(),
      learningModule4: (context) => const Module4Page(),
      learningModule5: (context) => const Module5Page(),
      commands: (context) => const UserCommandsPage(),
      apiKeysOnboarding: (context) => const ApiKeysOnboardingPage(),
      apiKeysSettings: (context) => const ApiKeysSettingsPage(),
    };
  }
}