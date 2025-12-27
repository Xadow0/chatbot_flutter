import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/command_folder_model.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Servicio para gestionar la persistencia local de carpetas de comandos.
/// Utiliza SecureStorage para mantener los datos cifrados.
class LocalFolderService {
  final SecureStorageService _secureStorage;
  
  static const String _storageKey = 'user_command_folders';

  LocalFolderService(this._secureStorage);

  /// Obtiene todas las carpetas del usuario
  Future<List<CommandFolderModel>> getFolders() async {
    try {
      final jsonString = await _secureStorage.read(key: _storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(jsonString);
      
      final folders = decodedList
          .map((item) => CommandFolderModel.fromJson(item as Map<String, dynamic>))
          .toList();
      
      // Ordenar por el campo order
      folders.sort((a, b) => a.order.compareTo(b.order));
      
      return folders;
          
    } catch (e) {
      debugPrint('❌ [LocalFolderService] Error al leer carpetas: $e');
      return [];
    }
  }

  /// Obtiene una carpeta por su ID
  Future<CommandFolderModel?> getFolderById(String folderId) async {
    try {
      final folders = await getFolders();
      return folders.firstWhere(
        (f) => f.id == folderId,
        orElse: () => throw Exception('Carpeta no encontrada'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Guarda una carpeta (crear o actualizar)
  Future<void> saveFolder(CommandFolderModel folder) async {
    try {
      final currentFolders = await getFolders();
      
      final index = currentFolders.indexWhere((f) => f.id == folder.id);

      if (index >= 0) {
        currentFolders[index] = folder;
        debugPrint('✏️ [LocalFolderService] Actualizando carpeta: ${folder.name}');
      } else {
        // Asignar order al final si es nueva
        final newOrder = currentFolders.isEmpty 
            ? 0 
            : currentFolders.map((f) => f.order).reduce((a, b) => a > b ? a : b) + 1;
        
        final folderWithOrder = folder.copyWith(order: newOrder);
        currentFolders.add(folderWithOrder);
        debugPrint('➕ [LocalFolderService] Creando carpeta: ${folder.name}');
      }

      await _saveListToStorage(currentFolders);
      
    } catch (e) {
      debugPrint('❌ [LocalFolderService] Error al guardar carpeta: $e');
      rethrow;
    }
  }

  /// Guarda múltiples carpetas (usado en sincronización)
  Future<void> saveFolders(List<CommandFolderModel> folders) async {
    try {
      final currentFolders = await getFolders();
      
      for (final folder in folders) {
        final index = currentFolders.indexWhere((f) => f.id == folder.id);
        
        if (index >= 0) {
          currentFolders[index] = folder;
        } else {
          currentFolders.add(folder);
        }
      }

      await _saveListToStorage(currentFolders);
      debugPrint('💾 [LocalFolderService] ${folders.length} carpetas guardadas');
      
    } catch (e) {
      debugPrint('❌ [LocalFolderService] Error al guardar carpetas: $e');
      rethrow;
    }
  }

  /// Elimina una carpeta por su ID
  Future<void> deleteFolder(String folderId) async {
    try {
      final currentFolders = await getFolders();
      
      final int initialLength = currentFolders.length;
      currentFolders.removeWhere((f) => f.id == folderId);
      
      if (currentFolders.length == initialLength) {
        debugPrint('⚠️ [LocalFolderService] Carpeta no encontrada: $folderId');
        return;
      }

      await _saveListToStorage(currentFolders);
      debugPrint('🗑️ [LocalFolderService] Carpeta eliminada: $folderId');
      
    } catch (e) {
      debugPrint('❌ [LocalFolderService] Error al eliminar carpeta: $e');
      rethrow;
    }
  }

  /// Reordena las carpetas según la lista de IDs proporcionada
  Future<List<CommandFolderModel>> reorderFolders(List<String> folderIds) async {
    try {
      final currentFolders = await getFolders();
      
      final reorderedFolders = <CommandFolderModel>[];
      
      for (int i = 0; i < folderIds.length; i++) {
        final folder = currentFolders.firstWhere(
          (f) => f.id == folderIds[i],
          orElse: () => throw Exception('Carpeta no encontrada: ${folderIds[i]}'),
        );
        reorderedFolders.add(folder.copyWith(order: i));
      }
      
      // Añadir carpetas que no estaban en la lista (por si acaso)
      for (final folder in currentFolders) {
        if (!folderIds.contains(folder.id)) {
          reorderedFolders.add(folder.copyWith(order: reorderedFolders.length));
        }
      }

      await _saveListToStorage(reorderedFolders);
      debugPrint('🔄 [LocalFolderService] Carpetas reordenadas');
      
      return reorderedFolders;
      
    } catch (e) {
      debugPrint('❌ [LocalFolderService] Error al reordenar carpetas: $e');
      rethrow;
    }
  }

  /// Elimina todas las carpetas del usuario
  Future<void> deleteAllFolders() async {
    try {
      await _secureStorage.delete(key: _storageKey);
      debugPrint('✅ [LocalFolderService] Todas las carpetas eliminadas');
    } catch (e) {
      debugPrint('❌ [LocalFolderService] Error al eliminar carpetas: $e');
      rethrow;
    }
  }

  /// Método privado para serializar y guardar la lista
  Future<void> _saveListToStorage(List<CommandFolderModel> folders) async {
    final List<Map<String, dynamic>> jsonList = 
        folders.map((f) => f.toJson()).toList();
    
    final String jsonString = jsonEncode(jsonList);
    
    await _secureStorage.write(key: _storageKey, value: jsonString);
  }
}