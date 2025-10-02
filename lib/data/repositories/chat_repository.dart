import '../models/message_model.dart';

/// Repositorio para manejar operaciones de chat
/// En el futuro, aquí se implementará la comunicación con APIs
abstract class ChatRepository {
  Future<Message> sendMessage(String content);
  Future<List<Message>> getMessageHistory();
  Future<void> clearHistory();
}

/// Implementación local del repositorio (para desarrollo/testing)
class LocalChatRepository implements ChatRepository {
  final List<Message> _localMessages = [];

  @override
  Future<Message> sendMessage(String content) async {
    // Simular delay de red
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Crear respuesta del bot
    final botMessage = Message.bot(
      '¡Hola! Recibí tu mensaje: $content',
    );
    
    _localMessages.add(botMessage);
    return botMessage;
  }

  @override
  Future<List<Message>> getMessageHistory() async {
    return List.unmodifiable(_localMessages);
  }

  @override
  Future<void> clearHistory() async {
    _localMessages.clear();
  }
}

/// Implementación con API (placeholder para futuro)
class ApiChatRepository implements ChatRepository {
  // final ApiClient _apiClient;
  
  // ApiChatRepository(this._apiClient);

  @override
  Future<Message> sendMessage(String content) async {
    // TODO: Implementar llamada a API
    // final response = await _apiClient.post('/chat', body: {'message': content});
    // return Message.fromJson(response.data);
    
    throw UnimplementedError('API integration pending');
  }

  @override
  Future<List<Message>> getMessageHistory() async {
    // TODO: Implementar recuperación de historial desde API
    throw UnimplementedError('API integration pending');
  }

  @override
  Future<void> clearHistory() async {
    // TODO: Implementar limpieza en servidor
    throw UnimplementedError('API integration pending');
  }
}