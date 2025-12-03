import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/command_model.dart';
import 'secure_storage_service.dart';

/// Servicio para gestionar la persistencia local de comandos personalizados.
/// Utiliza SecureStorage para mantener los prompts del usuario cifrados.
class LocalCommandService {
  final SecureStorageService _secureStorage;
  
  // Clave bajo la cual guardaremos el JSON con la lista de comandos
  static const String _storageKey = 'user_custom_commands_list';

  LocalCommandService(this._secureStorage);

  /// Obtiene SOLO los comandos creados por el usuario desde el almacenamiento
  Future<List<CommandModel>> getUserCommands() async {
    try {
      final jsonString = await _secureStorage.read(key: _storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(jsonString);
      
      return decodedList
          .map((item) => CommandModel.fromJson(item as Map<String, dynamic>))
          .toList();
          
    } catch (e) {
      debugPrint('❌ [LocalCommandService] Error al leer comandos: $e');
      // En caso de error de corrupción de datos, retornamos lista vacía 
      // para no romper la UI, pero logueamos el error.
      return [];
    }
  }

  /// Guarda un comando (Crear o Editar).
  /// Si el comando ya existe (mismo ID), lo actualiza.
  /// Si no existe, lo añade a la lista.
  Future<void> saveCommand(CommandModel command) async {
    try {
      // 1. Obtener lista actual
      final currentCommands = await getUserCommands();
      
      // 2. Buscar si ya existe
      final index = currentCommands.indexWhere((c) => c.id == command.id);

      if (index >= 0) {
        // ACTUALIZAR: Reemplazamos el existente
        currentCommands[index] = command;
        debugPrint('✏️ [LocalCommandService] Actualizando comando: ${command.trigger}');
      } else {
        // CREAR: Añadimos el nuevo
        currentCommands.add(command);
        debugPrint('➕ [LocalCommandService] Creando nuevo comando: ${command.trigger}');
      }

      // 3. Guardar la lista actualizada
      await _saveListToStorage(currentCommands);
      
    } catch (e) {
      debugPrint('❌ [LocalCommandService] Error al guardar comando: $e');
      rethrow;
    }
  }

  /// Elimina un comando por su ID
  Future<void> deleteCommand(String commandId) async {
    try {
      // 1. Obtener lista actual
      final currentCommands = await getUserCommands();
      
      // 2. Filtrar el comando a eliminar
      final int initialLength = currentCommands.length;
      currentCommands.removeWhere((c) => c.id == commandId);
      
      if (currentCommands.length == initialLength) {
        debugPrint('⚠️ [LocalCommandService] Intentando borrar comando inexistente: $commandId');
        return;
      }

      // 3. Guardar la lista actualizada
      await _saveListToStorage(currentCommands);
      debugPrint('🗑️ [LocalCommandService] Comando eliminado: $commandId');
      
    } catch (e) {
      debugPrint('❌ [LocalCommandService] Error al eliminar comando: $e');
      rethrow;
    }
  }

  /// Elimina TODOS los comandos personalizados del usuario del almacenamiento local
  /// Se usa cuando el usuario elimina su cuenta de forma permanente
  /// 
  /// IMPORTANTE: 
  /// - Los comandos del sistema NO se ven afectados (existen solo en código)
  /// - Esta operación es irreversible
  /// - Solo elimina comandos del almacenamiento local (no de Firebase)
  Future<void> deleteAllCommands() async {
    try {
      // Obtener la cantidad actual de comandos para logging
      final currentCommands = await getUserCommands();
      final commandCount = currentCommands.length;
      
      debugPrint('🗑️ [LocalCommandService] Eliminando $commandCount comandos de usuario...');
      
      // Eliminar la clave completa del almacenamiento seguro
      // Esto elimina todos los comandos de una sola vez
      await _secureStorage.delete(key: _storageKey);
      
      debugPrint('✅ [LocalCommandService] $commandCount comandos eliminados del almacenamiento local');
      
    } catch (e) {
      debugPrint('❌ [LocalCommandService] Error al eliminar todos los comandos: $e');
      rethrow;
    }
  }

  /// Método privado para serializar y guardar la lista en SecureStorage
  Future<void> _saveListToStorage(List<CommandModel> commands) async {
    // Convertimos la lista de objetos a lista de mapas JSON
    final List<Map<String, dynamic>> jsonList = 
        commands.map((cmd) => cmd.toJson()).toList();
    
    // Convertimos a String
    final String jsonString = jsonEncode(jsonList);
    
    // Guardamos cifrado
    await _secureStorage.write(key: _storageKey, value: jsonString);
  }
}