import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';

class ConversationRepository {
  static Future<Directory> _getConversationsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/conversations');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  static Future<void> saveConversation(List<Message> messages) async {
    if (messages.isEmpty) return;
    final dir = await _getConversationsDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/$timestamp.json');
    final jsonData = messages.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonData));
  }

  static Future<List<FileSystemEntity>> listConversations() async {
    final dir = await _getConversationsDir();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // más recientes primero
    return files;
  }

  static Future<List<Message>> loadConversation(File file) async {
    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content);
    return jsonList.map((e) => Message.fromJson(e)).toList();
  }

  static Future<void> deleteAllConversations() async {
    final dir = await _getConversationsDir();
    if (await dir.exists()) {
      await for (var file in dir.list()) {
        if (file is File) await file.delete();
      }
    }
  }
}

