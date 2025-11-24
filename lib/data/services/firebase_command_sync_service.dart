import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/command_model.dart';

class FirebaseCommandSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _commandsCollection = 'user_commands';
  
  CollectionReference? _getUserCommandsRef() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [FirebaseCommandSync] No hay usuario autenticado');
      return null;
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection(_commandsCollection);
  }

  Future<bool> saveCommandToFirebase(CommandModel command) async {
    try {
      final commandsRef = _getUserCommandsRef();
      if (commandsRef == null) return false;

      final data = command.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await commandsRef.doc(command.trigger).set(data);
      debugPrint('☁️ [FirebaseCommandSync] Comando guardado: ${command.trigger}');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseCommandSync] Error guardando comando: $e');
      return false;
    }
  }

  Future<bool> deleteCommandFromFirebase(String trigger) async {
    try {
      final commandsRef = _getUserCommandsRef();
      if (commandsRef == null) return false;

      await commandsRef.doc(trigger).delete();
      debugPrint('🗑️ [FirebaseCommandSync] Comando eliminado: $trigger');
      
      return true;
    } catch (e) {
      debugPrint('❌ [FirebaseCommandSync] Error eliminando comando: $e');
      return false;
    }
  }

  Future<List<CommandModel>> getCommandsFromFirebase() async {
    try {
      final commandsRef = _getUserCommandsRef();
      if (commandsRef == null) return [];

      final snapshot = await commandsRef.get();
      
      return snapshot.docs
          .map((doc) => CommandModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [FirebaseCommandSync] Error obteniendo comandos: $e');
      return [];
    }
  }

  Future<CommandSyncResult> syncCommands(List<CommandModel> localCommands) async {
    try {
      final commandsRef = _getUserCommandsRef();
      if (commandsRef == null) {
        return CommandSyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Usuario no autenticado',
        );
      }

      int uploaded = 0;
      int downloaded = 0;

      final remoteSnapshot = await commandsRef.get();
      final remoteCommands = remoteSnapshot.docs
          .map((doc) => CommandModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      final localTriggers = localCommands.map((c) => c.trigger).toSet();
      final remoteTriggers = remoteCommands.map((c) => c.trigger).toSet();

      for (final localCmd in localCommands) {
        if (!remoteTriggers.contains(localCmd.trigger)) {
          final success = await saveCommandToFirebase(localCmd);
          if (success) uploaded++;
        }
      }

      for (final remoteCmd in remoteCommands) {
        if (!localTriggers.contains(remoteCmd.trigger)) {
          downloaded++;
        }
      }

      debugPrint('✅ [FirebaseCommandSync] Sincronización completada: ↑$uploaded ↓$downloaded');
      
      return CommandSyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
        remoteCommands: remoteCommands,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseCommandSync] Error en sincronización: $e');
      return CommandSyncResult(
        success: false,
        uploaded: 0,
        downloaded: 0,
        error: e.toString(),
      );
    }
  }
}

class CommandSyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final String? error;
  final List<CommandModel>? remoteCommands;

  CommandSyncResult({
    required this.success,
    required this.uploaded,
    required this.downloaded,
    this.error,
    this.remoteCommands,
  });
}