/// Entidad de dominio para un modelo de Ollama
/// 
/// Representa un modelo de IA disponible en el servidor Ollama.
class OllamaModelEntity {
  final String name;
  final int size;
  final String digest;
  final DateTime modifiedAt;

  const OllamaModelEntity({
    required this.name,
    required this.size,
    required this.digest,
    required this.modifiedAt,
  });

  /// Obtiene el tamaño formateado en GB
  String get sizeFormatted {
    if (size == 0) return 'Unknown';
    final gb = size / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// Obtiene el nombre para mostrar sin el tag :latest
  String get displayName {
    return name.replaceAll(':latest', '');
  }

  /// Crea una copia del modelo con algunos campos modificados
  OllamaModelEntity copyWith({
    String? name,
    int? size,
    String? digest,
    DateTime? modifiedAt,
  }) {
    return OllamaModelEntity(
      name: name ?? this.name,
      size: size ?? this.size,
      digest: digest ?? this.digest,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OllamaModelEntity &&
        other.name == name &&
        other.size == size &&
        other.digest == digest &&
        other.modifiedAt == modifiedAt;
  }

  @override
  int get hashCode {
    return Object.hash(name, size, digest, modifiedAt);
  }

  @override
  String toString() {
    return 'OllamaModelEntity(name: $name, size: $sizeFormatted, modifiedAt: $modifiedAt)';
  }
}

/// Entidad de dominio para información de conexión con Ollama
class ConnectionInfoEntity {
  final ConnectionStatusEntity status;
  final String url;
  final bool isHealthy;
  final String? errorMessage;
  final OllamaHealthEntity? healthData;

  const ConnectionInfoEntity({
    required this.status,
    required this.url,
    required this.isHealthy,
    this.errorMessage,
    this.healthData,
  });

  /// Texto descriptivo del estado de conexión
  String get statusText {
    switch (status) {
      case ConnectionStatusEntity.connected:
        return '🟢 Conectado';
      case ConnectionStatusEntity.connecting:
        return '🟡 Conectando...';
      case ConnectionStatusEntity.disconnected:
        return '🔴 Desconectado';
      case ConnectionStatusEntity.error:
        return '❌ Error';
    }
  }

  /// URL formateada para visualización
  String get urlForDisplay {
    if (url.length > 40) {
      return '${url.substring(0, 25)}...${url.substring(url.length - 10)}';
    }
    return url;
  }

  ConnectionInfoEntity copyWith({
    ConnectionStatusEntity? status,
    String? url,
    bool? isHealthy,
    String? errorMessage,
    OllamaHealthEntity? healthData,
  }) {
    return ConnectionInfoEntity(
      status: status ?? this.status,
      url: url ?? this.url,
      isHealthy: isHealthy ?? this.isHealthy,
      errorMessage: errorMessage ?? this.errorMessage,
      healthData: healthData ?? this.healthData,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionInfoEntity &&
        other.status == status &&
        other.url == url &&
        other.isHealthy == isHealthy &&
        other.errorMessage == errorMessage &&
        other.healthData == healthData;
  }

  @override
  int get hashCode {
    return Object.hash(status, url, isHealthy, errorMessage, healthData);
  }
}

/// Estado de conexión con Ollama
enum ConnectionStatusEntity {
  connected,
  connecting,
  disconnected,
  error,
}

/// Entidad de dominio para la respuesta de salud de Ollama
class OllamaHealthEntity {
  final bool success;
  final String status;
  final bool ollamaAvailable;
  final int modelCount;
  final String? tailscaleIP;

  const OllamaHealthEntity({
    required this.success,
    required this.status,
    required this.ollamaAvailable,
    required this.modelCount,
    this.tailscaleIP,
  });

  OllamaHealthEntity copyWith({
    bool? success,
    String? status,
    bool? ollamaAvailable,
    int? modelCount,
    String? tailscaleIP,
  }) {
    return OllamaHealthEntity(
      success: success ?? this.success,
      status: status ?? this.status,
      ollamaAvailable: ollamaAvailable ?? this.ollamaAvailable,
      modelCount: modelCount ?? this.modelCount,
      tailscaleIP: tailscaleIP ?? this.tailscaleIP,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OllamaHealthEntity &&
        other.success == success &&
        other.status == status &&
        other.ollamaAvailable == ollamaAvailable &&
        other.modelCount == modelCount &&
        other.tailscaleIP == tailscaleIP;
  }

  @override
  int get hashCode {
    return Object.hash(success, status, ollamaAvailable, modelCount, tailscaleIP);
  }
}