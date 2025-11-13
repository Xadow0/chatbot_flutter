import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../models/message_model.dart';

/// Implementación del repositorio para gestionar conversaciones guardadas en ficheros.
/// 
/// IMPORTANTE: Este repositorio trabaja con ENTIDADES (domain layer)
/// y usa modelos (data layer) solo para persistencia JSON.
class ConversationRepositoryImpl implements ConversationRepository {
  
  Future<Directory> _getConversationsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/conversations');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Guarda una conversación completa (lista de entidades)
  @override
  Future<void> saveConversation(List<MessageEntity> messages, {String? suffix}) async {
    if (messages.isEmpty) return;
    
    final dir = await _getConversationsDir();
    final now = DateTime.now();
    
    // Días de la semana en español
    const daysOfWeek = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    
    // Meses en español
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    final dayName = daysOfWeek[now.weekday - 1];
    final dayNumber = now.day;
    final monthName = months[now.month - 1];
    final year = now.year;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    
    final suffixPart = suffix != null ? ', $suffix' : '';
    final fileName = '$dayName, $dayNumber de $monthName de $year, a las $hour horas $minute minutos$suffixPart.json';
    final file = File('${dir.path}/$fileName');
    
    final models = messages.map((entity) => Message.fromEntity(entity)).toList();
    final jsonData = models.map((m) => m.toJson()).toList();
    
    await file.writeAsString(jsonEncode(jsonData));
  }

  /// Lista todas las conversaciones guardadas
  @override
  Future<List<FileSystemEntity>> listConversations() async {
    final dir = await _getConversationsDir();
    final files = dir.listSync().whereType<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Carga una conversación específica (retorna entidades)
  @override
  Future<List<MessageEntity>> loadConversation(File file) async {
    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content);
    
    final models = jsonList.map((e) => Message.fromJson(e)).toList();
    return models.map((model) => model.toEntity()).toList();
  }

  /// Elimina todas las conversaciones
  @override
  Future<void> deleteAllConversations() async {
    final dir = await _getConversationsDir();
    if (await dir.exists()) {
      await for (var file in dir.list()) {
        if (file is File) await file.delete();
      }
    }
  }
  
  /// Elimina múltiples conversaciones
  @override
  Future<void> deleteConversations(List<File> files) async {
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}