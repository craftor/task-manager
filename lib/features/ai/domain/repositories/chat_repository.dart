import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String sessionId);
  Future<void> saveMessage(ChatMessage msg);
  Future<String> createSession();
  Stream<List<ChatMessage>> watchMessages(String sessionId);
}