import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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
    // Generate a valid UUID v4 for the session
    return const Uuid().v4();
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
    final roleStr = row['role'] as String?;
    final role = roleStr != null && ChatRole.values.any((r) => r.name == roleStr)
        ? ChatRole.values.firstWhere((r) => r.name == roleStr)
        : ChatRole.user;
    return ChatMessage(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      role: role,
      content: row['content'] as String? ?? '',
      toolCalls: (row['tool_calls'] as List?)?.map((t) => ToolCall(name: t['name'] as String, arguments: Map<String, dynamic>.from(t['arguments'] as Map))).toList(),
      toolResults: (row['tool_results'] as List?)?.map((t) => ToolResult(name: t['name'] as String, success: t['success'] as bool? ?? false, error: t['error'] as String?, result: t['result'])).toList(),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}