import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/chat_message.dart';
import '../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _client;

  ChatRepositoryImpl(this._client);

  @override
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final result = await _client
        .from('chat_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    return result.map(_mapRow).toList();
  }

  @override
  Future<void> saveMessage(ChatMessage msg) async {
    await _client.from('chat_messages').insert({
      'id': msg.id,
      'user_id': _client.auth.currentUser!.id,
      'session_id': msg.sessionId,
      'role': msg.role.name,
      'content': msg.content,
      'tool_calls': msg.toolCalls?.map((t) => {'name': t.name, 'arguments': t.arguments}).toList(),
      'tool_results': msg.toolResults?.map((t) => {'name': t.name, 'success': t.success, 'error': t.error, 'result': t.result}).toList(),
      'created_at': msg.createdAt.toIso8601String(),
    });
  }

  @override
  Future<String> createSession() async {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map((rows) => rows.map(_mapRow).toList());
  }

  ChatMessage _mapRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'],
      sessionId: row['session_id'],
      role: ChatRole.values.firstWhere((r) => r.name == row['role']),
      content: row['content'],
      toolCalls: (row['tool_calls'] as List?)?.map((t) => ToolCall(name: t['name'], arguments: Map<String, dynamic>.from(t['arguments']))).toList(),
      toolResults: (row['tool_results'] as List?)?.map((t) => ToolResult(name: t['name'], success: t['success'], error: t['error'], result: t['result'])).toList(),
      createdAt: DateTime.parse(row['created_at']),
    );
  }
}