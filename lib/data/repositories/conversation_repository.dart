// lib/data/repositories/conversation_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../models/message_model.dart';
import '../services/firebase_sync_service.dart';

/// Implementación del repositorio para gestionar conversaciones guardadas en ficheros.
/// 
/// IMPORTANTE: Este repositorio trabaja con ENTIDADES (domain layer)
/// y usa modelos (data layer) solo para persistencia JSON.
/// 
/// NUEVO: Integra sincronización con Firebase cuando está habilitada
class ConversationRepositoryImpl implements ConversationRepository {
  final FirebaseSyncService _syncService;
  final bool Function() _isSyncEnabled;

  ConversationRepositoryImpl({
    required FirebaseSyncService syncService,
    required bool Function() isSyncEnabled,
  })  : _syncService = syncService,
        _isSyncEnabled = isSyncEnabled;

  Future<Directory> _getConversationsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/conversations');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  /// Guarda una conversación completa (lista de entidades)
  /// Si sync está habilitado, también la guarda en Firebase
  @override
  Future<void> saveConversation(List<MessageEntity> messages, {String? suffix}) async {
    if (messages.isEmpty) return;
    
    final dir = await _getConversationsDir();
    final fileName = _syncService.generateFileName(suffix: suffix);
    final file = File('${dir.path}/$fileName');
    
    // Guardar localmente
    final models = messages.map((entity) => Message.fromEntity(entity)).toList();
    final jsonData = models.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonData));
    
    // Si sync está habilitado, guardar también en Firebase
    if (_isSyncEnabled()) {
      await _syncService.saveConversationToFirebase(messages, fileName);
    }
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
  /// Si sync está habilitado, elimina de local Y remoto
  /// Si sync está deshabilitado, solo elimina local y muestra advertencia
  @override
  Future<void> deleteAllConversations() async {
    final dir = await _getConversationsDir();
    
    if (await dir.exists()) {
      // Eliminar archivos locales
      await for (var file in dir.list()) {
        if (file is File) await file.delete();
      }
    }
    
    // Si sync está habilitado, eliminar también de Firebase
    if (_isSyncEnabled()) {
      await _syncService.deleteAllFromFirebase();
    }
  }
  
  /// Elimina múltiples conversaciones
  /// Si sync está habilitado, elimina de local Y remoto
  /// Si sync está deshabilitado, solo elimina local
  @override
  Future<void> deleteConversations(List<File> files) async {
    final fileNames = <String>[];
    
    for (final file in files) {
      if (await file.exists()) {
        fileNames.add(_getFileName(file));
        await file.delete();
      }
    }
    
    // Si sync está habilitado, eliminar también de Firebase
    if (_isSyncEnabled() && fileNames.isNotEmpty) {
      await _syncService.deleteMultipleFromFirebase(fileNames);
    }
  }

  /// Extrae el nombre del archivo sin la ruta completa
  String _getFileName(File file) {
    return file.path.split('/').last;
  }
}