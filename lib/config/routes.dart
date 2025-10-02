import 'package:flutter/material.dart';
import '../presentation/pages/chat/chat_page.dart';
import '../presentation/pages/settings/settings_page.dart';

class AppRoutes {
  static const String chat = '/';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes {
    return {
      chat: (context) => const ChatPage(),
      settings: (context) => const SettingsPage(),
    };
  }
}