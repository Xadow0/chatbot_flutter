import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../models/message_model.dart';
import '../../../auth/data/datasources/firebase_sync_service.dart';

/// Implementación del repositorio para gestionar conversaciones guardadas en ficheros.
/// 
/// IMPORTANTE: Este repositorio trabaja con ENTIDADES (domain layer)
/// y usa modelos (data layer) solo para persistencia JSON.
/// 
/// SINCRONIZACIÓN CON FIREBASE:
/// - Cuando sync está habilitado, las conversaciones se guardan en Firebase CIFRADAS
/// - El cifrado es manejado internamente por [FirebaseSyncService]
/// - El salt de cifrado debe estar inicializado antes de usar sync
///   (esto ocurre automáticamente al iniciar sesión con sync activo)
/// 
/// FLUJO DE DATOS:
/// 1. Guardar: Entidades → Modelos → JSON → Local + Firebase (cifrado)
/// 2. Cargar: JSON → Modelos → Entidades (descifrado si viene de Firebase)
/// 3. Eliminar: Local + Firebase (si sync activo)
class ConversationRepositoryImpl implements IConversationRepository {
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

  /// Guarda una conversación en almacenamiento local y Firebase (si sync activo).
  /// 
  /// [messages]: Lista de mensajes a guardar
  /// [existingFile]: Si se proporciona, actualiza el archivo existente en lugar de crear uno nuevo
  /// [suffix]: Sufijo opcional para el nombre del archivo (solo para archivos nuevos)
  /// 
  /// COMPORTAMIENTO CON SYNC:
  /// - Si sync está activo: guarda localmente + sube a Firebase CIFRADO
  /// - Si sync está desactivado: solo guarda localmente (sin cifrar)
  /// 
  /// MANEJO DE ERRORES:
  /// - Si falla el guardado en Firebase (ej: cifrado no inicializado),
  ///   la conversación se guarda localmente y se loguea el error.
  /// - El error de Firebase NO impide el guardado local.
  @override
  Future<void> saveConversation(List<MessageEntity> messages, {File? existingFile, String? suffix}) async {
    if (messages.isEmpty) return;
    
    File file;
    String fileName;

    if (existingFile != null) {
      // ESTRATEGIA DE ACTUALIZACIÓN:
      // Usamos el archivo existente. No cambiamos el nombre.
      file = existingFile;
      fileName = file.uri.pathSegments.last; 
    } else {
      // ESTRATEGIA DE CREACIÓN:
      // Generamos nombre nuevo solo si es una conversación nueva
      final dir = await _getConversationsDir();
      fileName = _syncService.generateFileName(suffix: suffix);
      file = File('${dir.path}/$fileName');
    }
    
    // 1. Guardar localmente (siempre, sin cifrar - el cifrado es solo para Firebase)
    final models = messages.map((entity) => Message.fromEntity(entity)).toList();
    final jsonData = models.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonData));
    
    // 2. Guardar en Firebase si sync está activo
    // El cifrado se maneja internamente en FirebaseSyncService
    if (_isSyncEnabled()) {
      try {
        final success = await _syncService.saveConversationToFirebase(messages, fileName);
        if (!success) {
          debugPrint('⚠️ [ConversationRepo] No se pudo guardar en Firebase (¿cifrado no inicializado?)');
        }
      } catch (e) {
        // No propagamos el error - la conversación ya está guardada localmente
        debugPrint('⚠️ [ConversationRepo] Error guardando en Firebase: $e');
        debugPrint('   → La conversación se guardó localmente. Se sincronizará después.');
      }
    }
  }

  /// Lista todas las conversaciones guardadas localmente.
  /// 
  /// Retorna los archivos ordenados por fecha de última modificación (más reciente primero).
  /// 
  /// NOTA: Este método solo lista archivos locales. Las conversaciones en Firebase
  /// que no estén localmente no aparecerán hasta que se sincronicen.
  @override
  Future<List<FileSystemEntity>> listConversations() async {
    final dir = await _getConversationsDir();
    
    // Verificación de seguridad: si no existe la carpeta, retornamos lista vacía
    if (!await dir.exists()) return [];

    // Obtenemos solo los archivos JSON
    final files = dir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    // Ordenamos por fecha de última modificación (más reciente primero)
    files.sort((a, b) {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

    return files;
  }

  /// Carga una conversación específica desde un archivo local.
  /// 
  /// [file]: Archivo JSON que contiene la conversación
  /// 
  /// Retorna la lista de mensajes como entidades del dominio.
  /// 
  /// NOTA: Los archivos locales NO están cifrados. El cifrado solo se aplica
  /// a los datos en Firebase. Cuando se descargan de Firebase, se descifran
  /// automáticamente antes de guardarse localmente.
  @override
  Future<List<MessageEntity>> loadConversation(File file) async {
    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      
      final models = jsonList.map((e) => Message.fromJson(e)).toList();
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      debugPrint('❌ [ConversationRepo] Error cargando conversación: $e');
      rethrow;
    }
  }

  /// Elimina todas las conversaciones locales y de Firebase (si sync activo).
  /// 
  /// COMPORTAMIENTO:
  /// - Siempre elimina todos los archivos locales
  /// - Si sync está activo: también elimina de Firebase
  /// - NO elimina el salt de cifrado (eso solo ocurre al eliminar la cuenta)
  /// 
  /// NOTA: Si sync está desactivado, las conversaciones en Firebase
  /// permanecerán intactas hasta que se reactive sync y se sincronice.
  @override
  Future<void> deleteAllConversations() async {
    final dir = await _getConversationsDir();
    
    if (await dir.exists()) {
      // Eliminar archivos locales
      int deletedCount = 0;
      await for (var file in dir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            await file.delete();
            deletedCount++;
          } catch (e) {
            debugPrint('⚠️ [ConversationRepo] Error eliminando ${file.path}: $e');
          }
        }
      }
      debugPrint('🗑️ [ConversationRepo] $deletedCount conversaciones locales eliminadas');
    }
    
    // Si sync está habilitado, eliminar también de Firebase
    if (_isSyncEnabled()) {
      try {
        final success = await _syncService.deleteAllFromFirebase();
        if (success) {
          debugPrint('🗑️ [ConversationRepo] Conversaciones eliminadas de Firebase');
        } else {
          debugPrint('⚠️ [ConversationRepo] Error eliminando de Firebase');
        }
      } catch (e) {
        debugPrint('⚠️ [ConversationRepo] Error eliminando de Firebase: $e');
      }
    }
  }
  
  /// Elimina múltiples conversaciones específicas.
  /// 
  /// [files]: Lista de archivos a eliminar
  /// 
  /// COMPORTAMIENTO:
  /// - Elimina los archivos locales especificados
  /// - Si sync está activo: también elimina de Firebase
  @override
  Future<void> deleteConversations(List<File> files) async {
    final fileNames = <String>[];
    int deletedCount = 0;
    
    for (final file in files) {
      if (await file.exists()) {
        try {
          fileNames.add(_getFileName(file));
          await file.delete();
          deletedCount++;
        } catch (e) {
          debugPrint('⚠️ [ConversationRepo] Error eliminando ${file.path}: $e');
        }
      }
    }
    
    debugPrint('🗑️ [ConversationRepo] $deletedCount conversaciones locales eliminadas');
    
    // Si sync está habilitado, eliminar también de Firebase
    if (_isSyncEnabled() && fileNames.isNotEmpty) {
      try {
        await _syncService.deleteMultipleFromFirebase(fileNames);
        debugPrint('🗑️ [ConversationRepo] ${fileNames.length} conversaciones eliminadas de Firebase');
      } catch (e) {
        debugPrint('⚠️ [ConversationRepo] Error eliminando de Firebase: $e');
      }
    }
  }

  /// Extrae el nombre del archivo de forma segura para cualquier SO
  String _getFileName(File file) {
    // file.uri normaliza la ruta y pathSegments maneja los separadores correctamente
    return file.uri.pathSegments.last;
  }
}