import '../../domain/entities/remote_ollama_entity.dart';

// Modelos específicos para Ollama
class OllamaModel {
  final String name;
  final int size;
  final String digest;
  final DateTime modifiedAt;

  OllamaModel({
    required this.name,
    required this.size,
    required this.digest,
    required this.modifiedAt,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] ?? '',
      size: json['size'] ?? 0,
      digest: json['digest'] ?? '',
      modifiedAt: DateTime.tryParse(json['modified_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get sizeFormatted {
    if (size == 0) return 'Unknown';
    final gb = size / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  String get displayName {
    // Mostrar nombre sin el tag :latest
    return name.replaceAll(':latest', '');
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  /// Convierte el modelo de datos a una entidad de dominio
  OllamaModelEntity toEntity() {
    return OllamaModelEntity(
      name: name,
      size: size,
      digest: digest,
      modifiedAt: modifiedAt,
    );
  }

  /// Crea un modelo de datos desde una entidad de dominio
  factory OllamaModel.fromEntity(OllamaModelEntity entity) {
    return OllamaModel(
      name: entity.name,
      size: entity.size,
      digest: entity.digest,
      modifiedAt: entity.modifiedAt,
    );
  }
}

class ChatMessage {
  final String role; // 'system', 'user', 'assistant'
  final String content;

  ChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
    );
  }
}

class OllamaHealthResponse {
  final bool success;
  final String status;
  final bool ollamaAvailable;
  final int modelCount;
  final String? tailscaleIP;

  OllamaHealthResponse({
    required this.success,
    required this.status,
    required this.ollamaAvailable,
    required this.modelCount,
    this.tailscaleIP,
  });

  factory OllamaHealthResponse.fromJson(Map<String, dynamic> json) {
    return OllamaHealthResponse(
      success: json['success'] ?? false,
      status: json['status'] ?? 'unknown',
      ollamaAvailable: json['ollama']?['available'] ?? false,
      modelCount: json['ollama']?['models'] ?? 0,
      tailscaleIP: json['tailscale']?['ip'],
    );
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  /// Convierte el modelo de datos a una entidad de dominio
  OllamaHealthEntity toEntity() {
    return OllamaHealthEntity(
      success: success,
      status: status,
      ollamaAvailable: ollamaAvailable,
      modelCount: modelCount,
      tailscaleIP: tailscaleIP,
    );
  }

  /// Crea un modelo de datos desde una entidad de dominio
  factory OllamaHealthResponse.fromEntity(OllamaHealthEntity entity) {
    return OllamaHealthResponse(
      success: entity.success,
      status: entity.status,
      ollamaAvailable: entity.ollamaAvailable,
      modelCount: entity.modelCount,
      tailscaleIP: entity.tailscaleIP,
    );
  }
}

enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  error,
}

class ConnectionInfo {
  final ConnectionStatus status;
  final String url;
  final bool isHealthy;
  final String? errorMessage;
  final OllamaHealthResponse? healthData;

  ConnectionInfo({
    required this.status,
    required this.url,
    required this.isHealthy,
    this.errorMessage,
    this.healthData,
  });

  String get statusText {
    switch (status) {
      case ConnectionStatus.connected:
        return '🟢 Conectado';
      case ConnectionStatus.connecting:
        return '🟡 Conectando...';
      case ConnectionStatus.disconnected:
        return '🔴 Desconectado';
      case ConnectionStatus.error:
        return '❌ Error';
    }
  }

  String get urlForDisplay {
    if (url.length > 40) {
      return '${url.substring(0, 25)}...${url.substring(url.length - 10)}';
    }
    return url;
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  /// Convierte el modelo de datos a una entidad de dominio
  ConnectionInfoEntity toEntity() {
    return ConnectionInfoEntity(
      status: _convertStatusToEntity(status),
      url: url,
      isHealthy: isHealthy,
      errorMessage: errorMessage,
      healthData: healthData?.toEntity(),
    );
  }

  /// Crea un modelo de datos desde una entidad de dominio
  factory ConnectionInfo.fromEntity(ConnectionInfoEntity entity) {
    return ConnectionInfo(
      status: _convertStatusFromEntity(entity.status),
      url: entity.url,
      isHealthy: entity.isHealthy,
      errorMessage: entity.errorMessage,
      healthData: entity.healthData != null
          ? OllamaHealthResponse.fromEntity(entity.healthData!)
          : null,
    );
  }

  static ConnectionStatusEntity _convertStatusToEntity(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return ConnectionStatusEntity.connected;
      case ConnectionStatus.connecting:
        return ConnectionStatusEntity.connecting;
      case ConnectionStatus.disconnected:
        return ConnectionStatusEntity.disconnected;
      case ConnectionStatus.error:
        return ConnectionStatusEntity.error;
    }
  }

  static ConnectionStatus _convertStatusFromEntity(
      ConnectionStatusEntity status) {
    switch (status) {
      case ConnectionStatusEntity.connected:
        return ConnectionStatus.connected;
      case ConnectionStatusEntity.connecting:
        return ConnectionStatus.connecting;
      case ConnectionStatusEntity.disconnected:
        return ConnectionStatus.disconnected;
      case ConnectionStatusEntity.error:
        return ConnectionStatus.error;
    }
  }
}

class OllamaException implements Exception {
  final String message;
  final int? statusCode;

  OllamaException(this.message, {this.statusCode});

  @override
  String toString() => 'OllamaException: $message';
}