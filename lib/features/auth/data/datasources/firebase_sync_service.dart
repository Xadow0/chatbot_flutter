// lib/features/auth/data/datasources/firebase_sync_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../chat/domain/entities/message_entity.dart';
import '../../../chat/data/models/message_model.dart';
import '../../../../core/services/conversation_encryption_service.dart';

/// Servicio para sincronizar conversaciones entre almacenamiento local y Firebase
/// 
/// Responsabilidades:
/// - Sincronización bidireccional al activar cloud sync
/// - Guardado automático en Firebase cuando sync está activo
/// - Eliminación sincronizada (local + remoto)
/// - Detección y resolución de conflictos
/// - **NUEVO**: Cifrado/descifrado automático de contenido en Firebase
class FirebaseSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConversationEncryptionService _encryptionService;
  
  static const String _conversationsCollection = 'conversations';
  
  FirebaseSyncService(this._encryptionService);

  /// Obtiene la referencia a la colección de conversaciones del usuario actual
  CollectionReference? _getUserConversationsRef() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [FirebaseSync] No hay usuario autenticado');
      return null;
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection(_conversationsCollection);
  }

  /// Obtiene el directorio local de conversaciones
  Future<Directory> _getConversationsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/conversations');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  // ==========================================================================
  // SINCRONIZACIÓN BIDIRECCIONAL
  // ==========================================================================

  /// Sincroniza conversaciones: sube las locales que faltan en Firebase
  /// y descarga las de Firebase que faltan localmente.
  /// 
  /// IMPORTANTE: Los datos se cifran al subir y se descifran al bajar.
  Future<SyncResult> syncConversations() async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) {
        return SyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Usuario no autenticado',
        );
      }

      int uploaded = 0;
      int downloaded = 0;

      // 1. Obtener archivos locales
      final localDir = await _getConversationsDir();
      final localFiles = localDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      
      final localFileNames = localFiles.map((f) => _getFileName(f)).toSet();

      // 2. Obtener documentos remotos
      final remoteSnapshot = await conversationsRef.get();
      final remoteFileNames = remoteSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      debugPrint('📊 [FirebaseSync] Local: ${localFileNames.length}, Remoto: ${remoteFileNames.length}');

      // 3. Subir archivos que existen en local pero no en remoto (con cifrado)
      for (final file in localFiles) {
        final fileName = _getFileName(file);
        if (!remoteFileNames.contains(fileName)) {
          final success = await _uploadConversation(file, conversationsRef);
          if (success) {
            uploaded++;
            debugPrint('⬆️ [FirebaseSync] Subido (cifrado): $fileName');
          }
        }
      }

      // 4. Descargar archivos que existen en remoto pero no en local (con descifrado)
      for (final doc in remoteSnapshot.docs) {
        final fileName = doc.id;
        if (!localFileNames.contains(fileName)) {
          final success = await _downloadConversation(doc, localDir);
          if (success) {
            downloaded++;
            debugPrint('⬇️ [FirebaseSync] Descargado (descifrado): $fileName');
          }
        }
      }

      debugPrint('✅ [FirebaseSync] Sincronización completada: ↑$uploaded ↓$downloaded');
      
      return SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error en sincronización: $e');
      return SyncResult(
        success: false,
        uploaded: 0,
        downloaded: 0,
        error: e.toString(),
      );
    }
  }

  /// Sube una conversación local a Firebase (CIFRADA)
  Future<bool> _uploadConversation(
    File file,
    CollectionReference conversationsRef,
  ) async {
    try {
      final fileName = _getFileName(file);
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      
      // Convertir a List<Map> para cifrar
      final messages = jsonList.cast<Map<String, dynamic>>();
      
      // 🔐 CIFRAR mensajes antes de subir
      final encryptedMessages = await _encryptionService.encryptMessages(messages);
      
      final data = {
        'messages': encryptedMessages,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
        'encrypted': true, // Marcador de que está cifrado
      };

      await conversationsRef.doc(fileName).set(data);
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error subiendo conversación: $e');
      return false;
    }
  }

  /// Descarga una conversación de Firebase al almacenamiento local (DESCIFRADA)
  Future<bool> _downloadConversation(
    QueryDocumentSnapshot doc,
    Directory localDir,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      final fileName = doc.id;
      final isEncrypted = data['encrypted'] == true;
      
      // 🔓 DESCIFRAR mensajes si están cifrados
      List<Map<String, dynamic>> finalMessages;
      if (isEncrypted) {
        finalMessages = await _encryptionService.decryptMessages(messages);
      } else {
        // Conversación antigua sin cifrar, mantener como está
        finalMessages = messages;
      }
      
      final file = File('${localDir.path}/$fileName');
      await file.writeAsString(jsonEncode(finalMessages));
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error descargando conversación: $e');
      return false;
    }
  }

  // ==========================================================================
  // GUARDADO EN FIREBASE (CIFRADO)
  // ==========================================================================

  /// Guarda una conversación en Firebase (cuando sync está activo)
  /// 
  /// El contenido se cifra automáticamente antes de subir.
  Future<bool> saveConversationToFirebase(
    List<MessageEntity> messages,
    String fileName,
  ) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      // Convertir entidades a modelos y luego a JSON
      final models = messages.map((entity) => Message.fromEntity(entity)).toList();
      final jsonData = models.map((m) => m.toJson()).toList();

      // 🔐 CIFRAR mensajes antes de guardar en Firebase
      final encryptedMessages = await _encryptionService.encryptMessages(jsonData);

      final data = {
        'messages': encryptedMessages,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
        'encrypted': true, // Marcador de cifrado
      };

      await conversationsRef.doc(fileName).set(data);
      debugPrint('☁️🔒 [FirebaseSync] Conversación guardada cifrada en Firebase: $fileName');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error guardando en Firebase: $e');
      return false;
    }
  }

  // ==========================================================================
  // CARGA DESDE FIREBASE (DESCIFRADO)
  // ==========================================================================

  /// Carga una conversación específica de Firebase y la descifra.
  /// Útil para obtener una conversación individual.
  Future<List<Map<String, dynamic>>?> loadConversationFromFirebase(
    String fileName,
  ) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return null;

      final doc = await conversationsRef.doc(fileName).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      final isEncrypted = data['encrypted'] == true;

      // 🔓 DESCIFRAR si está cifrado
      if (isEncrypted) {
        return await _encryptionService.decryptMessages(messages);
      }
      
      return messages;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error cargando de Firebase: $e');
      return null;
    }
  }

  // ==========================================================================
  // ELIMINACIÓN SINCRONIZADA
  // ==========================================================================

  /// Elimina una conversación de Firebase
  Future<bool> deleteConversationFromFirebase(String fileName) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      await conversationsRef.doc(fileName).delete();
      debugPrint('🗑️ [FirebaseSync] Conversación eliminada de Firebase: $fileName');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error eliminando de Firebase: $e');
      return false;
    }
  }

  /// Elimina múltiples conversaciones de Firebase
  Future<bool> deleteMultipleFromFirebase(List<String> fileNames) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      final batch = _firestore.batch();
      
      for (final fileName in fileNames) {
        batch.delete(conversationsRef.doc(fileName));
      }
      
      await batch.commit();
      debugPrint('🗑️ [FirebaseSync] ${fileNames.length} conversaciones eliminadas de Firebase');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error eliminando múltiples de Firebase: $e');
      return false;
    }
  }

  /// Elimina todas las conversaciones del usuario en Firebase
  Future<bool> deleteAllFromFirebase() async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      final snapshot = await conversationsRef.get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('🗑️ [FirebaseSync] Todas las conversaciones eliminadas de Firebase');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error eliminando todas de Firebase: $e');
      return false;
    }
  }

  // ==========================================================================
  // ELIMINACIÓN DE DATOS LOCALES (para eliminación de cuenta)
  // ==========================================================================

  /// Elimina todas las conversaciones locales del dispositivo
  /// Se usa cuando el usuario elimina su cuenta de forma permanente
  Future<void> deleteAllLocalConversations() async {
    try {
      final localDir = await _getConversationsDir();
      
      final files = localDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      
      debugPrint('🗑️ [FirebaseSync] Eliminando ${files.length} conversaciones locales...');
      
      int deletedCount = 0;
      for (final file in files) {
        try {
          await file.delete();
          deletedCount++;
          debugPrint('   ✔ Eliminado: ${_getFileName(file)}');
        } catch (e) {
          debugPrint('   ✗ Error eliminando ${_getFileName(file)}: $e');
        }
      }
      
      try {
        final remainingFiles = localDir.listSync();
        if (remainingFiles.isEmpty) {
          await localDir.delete();
          debugPrint('📁 [FirebaseSync] Directorio de conversaciones eliminado');
        }
      } catch (e) {
        debugPrint('⚠️ [FirebaseSync] No se pudo eliminar el directorio: $e');
      }
      
      debugPrint('✅ [FirebaseSync] $deletedCount conversaciones locales eliminadas');
      
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error al eliminar conversaciones locales: $e');
      rethrow;
    }
  }

  /// Elimina todos los datos del usuario tanto local como remotamente
  /// Se usa cuando se elimina la cuenta del usuario
  /// 
  /// NUEVO: También elimina el salt de cifrado
  Future<bool> deleteAllUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [FirebaseSync] No hay usuario autenticado');
        return false;
      }

      debugPrint('🗑️ [FirebaseSync] Iniciando eliminación completa de datos del usuario...');

      // 1. Eliminar conversaciones de Firebase
      final firebaseDeleted = await deleteAllFromFirebase();
      if (!firebaseDeleted) {
        debugPrint('⚠️ [FirebaseSync] Error al eliminar conversaciones de Firebase');
      }

      // 2. Eliminar conversaciones locales
      await deleteAllLocalConversations();

      // 3. 🔐 Eliminar salt de cifrado
      await _encryptionService.deleteUserSalt();

      // 4. Eliminar documento del usuario
      try {
        await _firestore.collection('users').doc(user.uid).delete();
        debugPrint('✅ [FirebaseSync] Documento de usuario eliminado');
      } catch (e) {
        debugPrint('⚠️ [FirebaseSync] Error al eliminar documento de usuario: $e');
      }

      debugPrint('✅ [FirebaseSync] Todos los datos del usuario eliminados');
      return true;

    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error eliminando datos del usuario: $e');
      return false;
    }
  }

  // ==========================================================================
  // MIGRACIÓN DE CONVERSACIONES EXISTENTES
  // ==========================================================================

  /// Migra conversaciones existentes sin cifrar a formato cifrado.
  /// Útil para actualizar datos antiguos.
  Future<MigrationResult> migrateToEncrypted() async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) {
        return MigrationResult(
          success: false,
          migrated: 0,
          error: 'Usuario no autenticado',
        );
      }

      final snapshot = await conversationsRef.get();
      int migrated = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Solo migrar si NO está cifrado
        if (data['encrypted'] != true) {
          final messages = (data['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
          
          // Cifrar mensajes
          final encryptedMessages = await _encryptionService.encryptMessages(messages);
          
          // Actualizar documento
          await conversationsRef.doc(doc.id).update({
            'messages': encryptedMessages,
            'encrypted': true,
            'migratedAt': FieldValue.serverTimestamp(),
          });
          
          migrated++;
          debugPrint('🔄 [FirebaseSync] Migrada: ${doc.id}');
        }
      }

      debugPrint('✅ [FirebaseSync] Migración completada: $migrated conversaciones');
      
      return MigrationResult(
        success: true,
        migrated: migrated,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error en migración: $e');
      return MigrationResult(
        success: false,
        migrated: 0,
        error: e.toString(),
      );
    }
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  /// Extrae el nombre del archivo sin la ruta completa
  String _getFileName(File file) {
    return file.path.split('/').last;
  }

  /// Genera el nombre de archivo basado en el timestamp y sufijo opcional
  String generateFileName({String? suffix}) {
    final now = DateTime.now();
    
    const daysOfWeek = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
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
    return '$dayName, $dayNumber de $monthName de $year, a las $hour horas $minute minutos$suffixPart.json';
  }

  /// Limpia el cache de cifrado (llamar al cerrar sesión)
  void clearEncryptionCache() {
    _encryptionService.clearCache();
  }
}

/// Resultado de una operación de sincronización
class SyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final String? error;

  SyncResult({
    required this.success,
    required this.uploaded,
    required this.downloaded,
    this.error,
  });

  @override
  String toString() {
    if (!success) return 'Error: $error';
    return 'Sincronizado: $uploaded subidos, $downloaded descargados';
  }
}

/// Resultado de una operación de migración
class MigrationResult {
  final bool success;
  final int migrated;
  final String? error;

  MigrationResult({
    required this.success,
    required this.migrated,
    this.error,
  });

  @override
  String toString() {
    if (!success) return 'Error: $error';
    return 'Migradas: $migrated conversaciones';
  }
}