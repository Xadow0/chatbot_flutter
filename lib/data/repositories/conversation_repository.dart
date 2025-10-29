import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';

/// Repositorio para gestionar conversaciones guardadas
/// 
/// IMPORTANTE: Este repositorio trabaja con ENTIDADES (domain layer)
/// y usa modelos (data layer) solo para persistencia JSON.
class ConversationRepository {
  static Future<Directory> _getConversationsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/conversations');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Guarda una conversación completa (lista de entidades)
  static Future<void> saveConversation(List<MessageEntity> messages) async {
    if (messages.isEmpty) return;
    
    final dir = await _getConversationsDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/$timestamp.json');
    
    // Convertir entidades a modelos para serialización JSON
    final models = messages.map((entity) => Message.fromEntity(entity)).toList();
    final jsonData = models.map((m) => m.toJson()).toList();
    
    await file.writeAsString(jsonEncode(jsonData));
  }

  /// Lista todas las conversaciones guardadas
  static Future<List<FileSystemEntity>> listConversations() async {
    final dir = await _getConversationsDir();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // más recientes primero
    return files;
  }

  /// Carga una conversación específica (retorna entidades)
  static Future<List<MessageEntity>> loadConversation(File file) async {
    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content);
    
    // Deserializar JSON a modelos
    final models = jsonList.map((e) => Message.fromJson(e)).toList();
    
    // Convertir modelos a entidades
    return models.map((model) => model.toEntity()).toList();
  }

  /// Elimina todas las conversaciones
  static Future<void> deleteAllConversations() async {
    final dir = await _getConversationsDir();
    if (await dir.exists()) {
      await for (var file in dir.list()) {
        if (file is File) await file.delete();
      }
    }
  }
}