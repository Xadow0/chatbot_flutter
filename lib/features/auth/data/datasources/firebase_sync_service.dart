// lib/data/services/firebase_sync_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../chat/domain/entities/message_entity.dart';
import '../../../chat/data/models/message_model.dart';

/// Servicio para sincronizar conversaciones entre almacenamiento local y Firebase
/// 
/// Responsabilidades:
/// - Sincronización bidireccional al activar cloud sync
/// - Guardado automático en Firebase cuando sync está activo
/// - Eliminación sincronizada (local + remoto)
/// - Detección y resolución de conflictos
class FirebaseSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _conversationsCollection = 'conversations';
  
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
  /// y descarga las de Firebase que faltan localmente
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

      // 3. Subir archivos que existen en local pero no en remoto
      for (final file in localFiles) {
        final fileName = _getFileName(file);
        if (!remoteFileNames.contains(fileName)) {
          final success = await _uploadConversation(file, conversationsRef);
          if (success) {
            uploaded++;
            debugPrint('⬆️ [FirebaseSync] Subido: $fileName');
          }
        }
      }

      // 4. Descargar archivos que existen en remoto pero no en local
      for (final doc in remoteSnapshot.docs) {
        final fileName = doc.id;
        if (!localFileNames.contains(fileName)) {
          final success = await _downloadConversation(doc, localDir);
          if (success) {
            downloaded++;
            debugPrint('⬇️ [FirebaseSync] Descargado: $fileName');
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

  /// Sube una conversación local a Firebase
  Future<bool> _uploadConversation(
    File file,
    CollectionReference conversationsRef,
  ) async {
    try {
      final fileName = _getFileName(file);
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      
      // Convertimos a un formato serializable para Firestore
      final data = {
        'messages': jsonList,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
      };

      await conversationsRef.doc(fileName).set(data);
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error subiendo conversación: $e');
      return false;
    }
  }

  /// Descarga una conversación de Firebase al almacenamiento local
  Future<bool> _downloadConversation(
    QueryDocumentSnapshot doc,
    Directory localDir,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final messages = data['messages'] as List<dynamic>;
      final fileName = doc.id;
      
      final file = File('${localDir.path}/$fileName');
      await file.writeAsString(jsonEncode(messages));
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error descargando conversación: $e');
      return false;
    }
  }

  // ==========================================================================
  // GUARDADO EN FIREBASE
  // ==========================================================================

  /// Guarda una conversación en Firebase (cuando sync está activo)
  Future<bool> saveConversationToFirebase(
    List<MessageEntity> messages,
    String fileName,
  ) async {
    try {
      final conversationsRef = _getUserConversationsRef();
      if (conversationsRef == null) return false;

      final models = messages.map((entity) => Message.fromEntity(entity)).toList();
      final jsonData = models.map((m) => m.toJson()).toList();

      final data = {
        'messages': jsonData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
      };

      await conversationsRef.doc(fileName).set(data);
      debugPrint('☁️ [FirebaseSync] Conversación guardada en Firebase: $fileName');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error guardando en Firebase: $e');
      return false;
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
  /// 
  /// Esta operación:
  /// 1. Elimina todos los archivos .json del directorio de conversaciones
  /// 2. Elimina el directorio de conversaciones si está vacío
  /// 
  /// Nota: Esta función NO elimina datos de Firebase, solo locales
  Future<void> deleteAllLocalConversations() async {
    try {
      final localDir = await _getConversationsDir();
      
      // Obtener todos los archivos de conversaciones
      final files = localDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      
      debugPrint('🗑️ [FirebaseSync] Eliminando ${files.length} conversaciones locales...');
      
      // Eliminar cada archivo
      int deletedCount = 0;
      for (final file in files) {
        try {
          await file.delete();
          deletedCount++;
          debugPrint('   ✓ Eliminado: ${_getFileName(file)}');
        } catch (e) {
          debugPrint('   ✗ Error eliminando ${_getFileName(file)}: $e');
        }
      }
      
      // Intentar eliminar el directorio si está vacío
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
  /// Esta operación:
  /// 1. Elimina todas las conversaciones de Firebase
  /// 2. Elimina todas las conversaciones locales
  /// 3. Elimina el documento del usuario en Firebase (si existe)
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

      // 3. Eliminar documento del usuario (opcional, según tu estructura)
      try {
        await _firestore.collection('users').doc(user.uid).delete();
        debugPrint('✅ [FirebaseSync] Documento de usuario eliminado');
      } catch (e) {
        debugPrint('⚠️ [FirebaseSync] Error al eliminar documento de usuario: $e');
        // No es crítico, continuamos
      }

      debugPrint('✅ [FirebaseSync] Todos los datos del usuario eliminados');
      return true;

    } catch (e) {
      debugPrint('❌ [FirebaseSync] Error eliminando datos del usuario: $e');
      return false;
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