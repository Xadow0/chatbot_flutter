import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/command_folder_model.dart';

/// Servicio para sincronizar carpetas de comandos y preferencias con Firebase
/// 
/// Responsabilidades:
/// - CRUD de carpetas en Firebase
/// - Sincronización bidireccional de carpetas
/// - Sincronización de preferencias de comandos (groupSystemCommands)
/// - Mantener consistencia entre local y remoto
class FirebaseFolderSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _foldersCollection = 'command_folders';
  static const String _preferencesDoc = 'command_preferences';
  
  /// Obtiene la referencia a la colección de carpetas del usuario actual
  CollectionReference? _getUserFoldersRef() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [FirebaseFolderSync] No hay usuario autenticado');
      return null;
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection(_foldersCollection);
  }

  /// Obtiene la referencia al documento de preferencias del usuario
  DocumentReference? _getUserPreferencesRef() {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc(_preferencesDoc);
  }

  // ==========================================================================
  // PREFERENCIAS DE COMANDOS
  // ==========================================================================

  /// Guarda la preferencia de agrupar comandos del sistema en Firebase
  Future<bool> saveGroupSystemPreference(bool groupSystemCommands) async {
    try {
      final prefsRef = _getUserPreferencesRef();
      if (prefsRef == null) return false;

      await prefsRef.set({
        'groupSystemCommands': groupSystemCommands,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('☁️ [FirebaseFolderSync] Preferencia guardada: groupSystemCommands=$groupSystemCommands');
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error guardando preferencia: $e');
      return false;
    }
  }

  /// Obtiene la preferencia de agrupar comandos del sistema desde Firebase
  Future<bool?> getGroupSystemPreference() async {
    try {
      final prefsRef = _getUserPreferencesRef();
      if (prefsRef == null) return null;

      final doc = await prefsRef.get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['groupSystemCommands'] as bool?;
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error obteniendo preferencia: $e');
      return null;
    }
  }

  // ==========================================================================
  // CRUD DE CARPETAS EN FIREBASE
  // ==========================================================================

  /// Guarda una carpeta en Firebase
  Future<bool> saveFolderToFirebase(CommandFolderModel folder) async {
    try {
      final foldersRef = _getUserFoldersRef();
      if (foldersRef == null) return false;

      final data = folder.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await foldersRef.doc(folder.id).set(data);
      debugPrint('☁️ [FirebaseFolderSync] Carpeta guardada: ${folder.name}');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error guardando carpeta: $e');
      return false;
    }
  }

  /// Elimina una carpeta de Firebase
  Future<bool> deleteFolderFromFirebase(String folderId) async {
    try {
      final foldersRef = _getUserFoldersRef();
      if (foldersRef == null) return false;

      await foldersRef.doc(folderId).delete();
      debugPrint('🗑️ [FirebaseFolderSync] Carpeta eliminada: $folderId');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error eliminando carpeta: $e');
      return false;
    }
  }

  /// Obtiene todas las carpetas desde Firebase
  Future<List<CommandFolderModel>> getFoldersFromFirebase() async {
    try {
      final foldersRef = _getUserFoldersRef();
      if (foldersRef == null) return [];

      final snapshot = await foldersRef.orderBy('order').get();
      
      return snapshot.docs
          .map((doc) => CommandFolderModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error obteniendo carpetas: $e');
      return [];
    }
  }

  /// Actualiza el orden de las carpetas en Firebase
  Future<bool> reorderFoldersInFirebase(List<CommandFolderModel> folders) async {
    try {
      final foldersRef = _getUserFoldersRef();
      if (foldersRef == null) return false;

      final batch = _firestore.batch();
      
      for (final folder in folders) {
        final data = folder.toJson();
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(foldersRef.doc(folder.id), data);
      }
      
      await batch.commit();
      debugPrint('🔄 [FirebaseFolderSync] Orden de carpetas actualizado');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error reordenando carpetas: $e');
      return false;
    }
  }

  // ==========================================================================
  // SINCRONIZACIÓN BIDIRECCIONAL
  // ==========================================================================

  /// Sincroniza carpetas y preferencias: sube las locales que faltan en Firebase
  /// y descarga las de Firebase que faltan localmente
  Future<FolderSyncResult> syncFolders(List<CommandFolderModel> localFolders) async {
    try {
      final foldersRef = _getUserFoldersRef();
      if (foldersRef == null) {
        return FolderSyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Usuario no autenticado',
        );
      }

      int uploaded = 0;
      int downloaded = 0;

      // 1. Obtener carpetas remotas
      final remoteSnapshot = await foldersRef.get();
      final remoteFolders = remoteSnapshot.docs
          .map((doc) => CommandFolderModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      final localIds = localFolders.map((f) => f.id).toSet();
      final remoteIds = remoteFolders.map((f) => f.id).toSet();

      debugPrint('📊 [FirebaseFolderSync] Local: ${localIds.length}, Remoto: ${remoteIds.length}');

      // 2. Subir carpetas que existen en local pero no en remoto
      for (final localFolder in localFolders) {
        if (!remoteIds.contains(localFolder.id)) {
          final success = await saveFolderToFirebase(localFolder);
          if (success) {
            uploaded++;
            debugPrint('⬆️ [FirebaseFolderSync] Subida: ${localFolder.name}');
          }
        }
      }

      // 3. Identificar carpetas que existen en remoto pero no en local
      final foldersToDownload = <CommandFolderModel>[];
      for (final remoteFolder in remoteFolders) {
        if (!localIds.contains(remoteFolder.id)) {
          foldersToDownload.add(remoteFolder);
          downloaded++;
          debugPrint('⬇️ [FirebaseFolderSync] Para descargar: ${remoteFolder.name}');
        }
      }

      // 4. Sincronizar preferencia de agrupar sistema
      final remoteGroupPref = await getGroupSystemPreference();

      debugPrint('✅ [FirebaseFolderSync] Sincronización completada: ↑$uploaded ↓$downloaded');
      
      return FolderSyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
        remoteFolders: remoteFolders,
        foldersToDownload: foldersToDownload,
        remoteGroupSystemCommands: remoteGroupPref,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error en sincronización: $e');
      return FolderSyncResult(
        success: false,
        uploaded: 0,
        downloaded: 0,
        error: e.toString(),
      );
    }
  }

  // ==========================================================================
  // ELIMINACIÓN MASIVA
  // ==========================================================================

  /// Elimina todas las carpetas y preferencias del usuario en Firebase
  Future<bool> deleteAllFromFirebase() async {
    try {
      final foldersRef = _getUserFoldersRef();
      final prefsRef = _getUserPreferencesRef();
      
      if (foldersRef == null) return false;

      // Eliminar carpetas
      final snapshot = await foldersRef.get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Eliminar preferencias
      if (prefsRef != null) {
        batch.delete(prefsRef);
      }
      
      await batch.commit();
      debugPrint('🗑️ [FirebaseFolderSync] Todas las carpetas y preferencias eliminadas de Firebase');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseFolderSync] Error eliminando datos: $e');
      return false;
    }
  }
}

/// Resultado de una operación de sincronización de carpetas
class FolderSyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final String? error;
  final List<CommandFolderModel>? remoteFolders;
  final List<CommandFolderModel>? foldersToDownload;
  final bool? remoteGroupSystemCommands;

  FolderSyncResult({
    required this.success,
    required this.uploaded,
    required this.downloaded,
    this.error,
    this.remoteFolders,
    this.foldersToDownload,
    this.remoteGroupSystemCommands,
  });

  @override
  String toString() {
    if (!success) return 'Error: $error';
    return 'Sincronizado: $uploaded subidas, $downloaded descargadas';
  }
}