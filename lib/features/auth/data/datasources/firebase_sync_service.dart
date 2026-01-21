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
/// - Cifrado/descifrado automático de contenido en Firebase
/// - **NUEVO**: Sincronización de salt cifrado para multi-dispositivo
class FirebaseSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConversationEncryptionService _encryptionService;
  
  static const String _conversationsCollection = 'conversations';
  static const String _encryptionMetadataDoc = 'encryption_metadata';
  
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

  /// Obtiene la referencia al documento del usuario actual
  DocumentReference? _getUserDocRef() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [FirebaseSync] No hay usuario autenticado');
      return null;
    }
    
    return _firestore.collection('users').doc(user.uid);
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
  // GESTIÓN DE SALT CIFRADO EN FIREBASE
  // ==========================================================================

  /// Obtiene el salt cifrado almacenado en Firebase (si existe)
  Future<EncryptedSaltData?> getEncryptedSaltFromFirebase() async {
    try {
      final userDoc = _getUserDocRef();
      if (userDoc == null) return null;

      final doc = await userDoc.get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      final encryptedSalt = data['encryptedSalt'] as String?;
      final saltVersion = data['saltVersion'] as String?;
      
      if (encryptedSalt == null || encryptedSalt.isEmpty) {
        return null;
      }
      
      debugPrint('📥 [FirebaseSync] Salt cifrado encontrado en Firebase');
      return EncryptedSaltData(
        encryptedSalt: encryptedSalt,
        saltVersion: saltVersion ?? '',
      );
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error obteniendo salt de Firebase: $e');
      return null;
    }
  }

  /// Guarda el salt cifrado en Firebase
  Future<bool> saveEncryptedSaltToFirebase({
    required String encryptedSalt,
    required String saltVersion,
  }) async {
    try {
      final userDoc = _getUserDocRef();
      if (userDoc == null) return false;

      await userDoc.set({
        'encryptedSalt': encryptedSalt,
        'saltVersion': saltVersion,
        'saltUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('📤 [FirebaseSync] Salt cifrado guardado en Firebase');
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error guardando salt en Firebase: $e');
      return false;
    }
  }

  /// Elimina el salt cifrado de Firebase
  Future<bool> deleteEncryptedSaltFromFirebase() async {
    try {
      final userDoc = _getUserDocRef();
      if (userDoc == null) return false;

      await userDoc.update({
        'encryptedSalt': FieldValue.delete(),
        'saltVersion': FieldValue.delete(),
        'saltUpdatedAt': FieldValue.delete(),
      });
      
      debugPrint('🗑️ [FirebaseSync] Salt cifrado eliminado de Firebase');
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error eliminando salt de Firebase: $e');
      return false;
    }
  }

  /// Inicializa el cifrado para sincronización.
  /// 
  /// Este método es llamado AUTOMÁTICAMENTE durante el login (si sync activo)
  /// o al activar sync. Maneja la lógica de:
  /// - Descargar y descifrar salt de Firebase (dispositivo nuevo)
  /// - Generar y subir salt nuevo (usuario nuevo)
  /// - Verificar que el salt local está sincronizado
  /// 
  /// [password]: Contraseña del usuario (la misma del login)
  /// 
  /// Retorna [SaltSyncResult] indicando el resultado de la operación.
  Future<SaltSyncResult> initializeEncryptionForSync(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return SaltSyncResult(
          success: false,
          error: 'Usuario no autenticado',
        );
      }

      debugPrint('🔐 [FirebaseSync] Inicializando cifrado para ${user.uid.substring(0, 8)}...');

      // 1. Verificar si hay salt en Firebase
      final firebaseSaltData = await getEncryptedSaltFromFirebase();
      
      // 2. Inicializar el servicio de cifrado con la contraseña
      final initResult = await _encryptionService.initializeWithPassword(
        encryptedSaltFromFirebase: firebaseSaltData?.encryptedSalt,
        saltVersionFromFirebase: firebaseSaltData?.saltVersion,
        password: password,
      );
      
      if (!initResult.success) {
        return SaltSyncResult(
          success: false,
          error: initResult.error ?? 'Error inicializando cifrado',
        );
      }
      
      // 3. Si necesita subir salt a Firebase, hacerlo
      if (initResult.needsUpload && 
          initResult.encryptedSalt != null &&
          initResult.saltVersion != null) {
        final uploadSuccess = await saveEncryptedSaltToFirebase(
          encryptedSalt: initResult.encryptedSalt!,
          saltVersion: initResult.saltVersion!,
        );
        
        if (!uploadSuccess) {
          return SaltSyncResult(
            success: false,
            error: 'Error subiendo salt cifrado a Firebase',
          );
        }
        
        debugPrint('📤 [FirebaseSync] Salt cifrado subido a Firebase');
      }
      
      debugPrint('✅ [FirebaseSync] Cifrado inicializado correctamente');
      return SaltSyncResult(
        success: true,
        wasNewSaltGenerated: initResult.needsUpload,
      );
      
    } on InvalidPasswordException catch (e) {
      debugPrint('❌ [FirebaseSync] Contraseña incorrecta: $e');
      return SaltSyncResult(
        success: false,
        error: 'Contraseña incorrecta',
        isPasswordError: true,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error inicializando cifrado: $e');
      return SaltSyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // ==========================================================================
  // SINCRONIZACIÓN BIDIRECCIONAL
  // ==========================================================================

  /// Sincroniza conversaciones: sube las locales que faltan en Firebase
  /// y descarga las de Firebase que faltan localmente.
  /// 
  /// IMPORTANTE: 
  /// - Los datos se cifran al subir y se descifran al bajar.
  /// - Requiere que el salt esté inicializado previamente.
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

      // Verificar que tenemos salt para cifrar/descifrar
      final hasLocalSalt = await _encryptionService.hasLocalSalt();
      if (!hasLocalSalt) {
        return SyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Salt de cifrado no inicializado. Ejecuta initializeEncryptionForSync primero.',
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

  /// Actualiza una conversación existente en Firebase
  Future<bool> updateConversationInFirebase(
    List<MessageEntity> messages,
    String fileName,
  ) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      final models = messages.map((entity) => Message.fromEntity(entity)).toList();
      final jsonData = models.map((m) => m.toJson()).toList();
      
      // 🔐 CIFRAR mensajes
      final encryptedMessages = await _encryptionService.encryptMessages(jsonData);

      await conversationsRef.doc(fileName).update({
        'messages': encryptedMessages,
        'updatedAt': FieldValue.serverTimestamp(),
        'encrypted': true,
      });

      debugPrint('☁️🔒 [FirebaseSync] Conversación actualizada cifrada en Firebase: $fileName');
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error actualizando en Firebase: $e');
      return false;
    }
  }

  // ==========================================================================
  // ELIMINACIÓN
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

  /// Elimina todas las conversaciones de Firebase (pero mantiene el salt)
  Future<bool> deleteAllFromFirebase() async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      final snapshot = await conversationsRef.get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ [FirebaseSync] No hay conversaciones que eliminar');
        return true;
      }

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

  /// Elimina múltiples conversaciones específicas de Firebase
  /// 
  /// [fileNames]: Lista de nombres de archivo a eliminar
  /// 
  /// Usa batch write para eficiencia cuando hay múltiples archivos.
  Future<bool> deleteMultipleFromFirebase(List<String> fileNames) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      if (fileNames.isEmpty) {
        debugPrint('ℹ️ [FirebaseSync] No hay conversaciones que eliminar');
        return true;
      }

      // Usar batch para eliminar múltiples documentos eficientemente
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
  /// Incluye: conversaciones, salt cifrado, y documento de usuario
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

      // 3. 🔐 Eliminar salt de cifrado (local)
      await _encryptionService.deleteUserSalt();

      // 4. Eliminar documento del usuario (incluye salt cifrado)
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

// ==========================================================================
// CLASES DE RESULTADO
// ==========================================================================

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

/// Datos del salt cifrado almacenado en Firebase
class EncryptedSaltData {
  final String encryptedSalt;
  final String saltVersion;

  EncryptedSaltData({
    required this.encryptedSalt,
    required this.saltVersion,
  });
}

/// Resultado de la sincronización del salt
class SaltSyncResult {
  final bool success;
  final bool wasNewSaltGenerated;
  final String? error;
  final bool isPasswordError;

  SaltSyncResult({
    required this.success,
    this.wasNewSaltGenerated = false,
    this.error,
    this.isPasswordError = false,
  });
}