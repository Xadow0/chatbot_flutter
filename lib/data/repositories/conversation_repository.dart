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

  /// Modificado: Acepta 'existingFile' opcional para sobrescribir en lugar de crear nuevo
  @override
  Future<void> saveConversation(List<MessageEntity> messages, {File? existingFile, String? suffix}) async {
    if (messages.isEmpty) return;
    
    File file;
    String fileName;

    if (existingFile != null) {
      // ESTRATEGIA DE ACTUALIZACIÓN:
      // Usamos el archivo existente. No cambiamos el nombre.
      file = existingFile;
      // Usamos la lógica segura de nombre que implementamos antes
      fileName = file.uri.pathSegments.last; 
    } else {
      // ESTRATEGIA DE CREACIÓN:
      // Generamos nombre nuevo solo si es una conversación nueva
      final dir = await _getConversationsDir();
      fileName = _syncService.generateFileName(suffix: suffix);
      file = File('${dir.path}/$fileName');
    }
    
    // 1. Guardar localmente (Sobrescribe si existe, crea si no)
    final models = messages.map((entity) => Message.fromEntity(entity)).toList();
    final jsonData = models.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonData));
    
    // 2. Guardar en Firebase (El método .set() de Firestore actúa como 'Upsert', actualizando si existe)
    if (_isSyncEnabled()) {
      await _syncService.saveConversationToFirebase(messages, fileName);
    }
  }

  /// Lista todas las conversaciones guardadas
  @override
  Future<List<FileSystemEntity>> listConversations() async {
    final dir = await _getConversationsDir();
    
    // Verificación de seguridad: si no existe la carpeta, retornamos lista vacía
    if (!await dir.exists()) return [];

    // Obtenemos solo los archivos
    final files = dir.listSync().whereType<File>().toList();

    // CAMBIO APLICADO:
    // Ordenamos usando la fecha de "última modificación" del sistema de archivos.
    // Usamos (b, a) para orden descendente (más reciente primero).
    files.sort((a, b) {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

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

  /// Extrae el nombre del archivo de forma segura para cualquier SO
  String _getFileName(File file) {
    // file.uri normaliza la ruta y pathSegments maneja los separadores correctamente
    return file.uri.pathSegments.last;
  }
}