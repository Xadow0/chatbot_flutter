import 'package:flutter/material.dart';
import '../presentation/pages/chat/chat_page.dart';
import '../presentation/pages/settings/settings_page.dart';
import '../presentation/pages/menu/start_menu_page.dart';
import '../presentation/pages/history/history_page.dart';

class AppRoutes {
  static const String startMenu = '/';
  static const String chat = '/chat';
  static const String settings = '/settings';
  static const String history = '/history';

  static Map<String, WidgetBuilder> get routes {
    return {
      startMenu: (context) => const StartMenuPage(),
      chat: (context) => const ChatPage(),
      settings: (context) => const SettingsPage(),
      history: (context) => const HistoryPage(),
    };
  }
}
