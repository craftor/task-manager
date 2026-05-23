class ChatMessage {
  final String id;
  final String sessionId;
  final ChatRole role;
  final String content;
  final List<ToolCall>? toolCalls;
  final List<ToolResult>? toolResults;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolResults,
    required this.createdAt,
  });
}

enum ChatRole { user, assistant, system }

class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  ToolCall({required this.name, required this.arguments});
}

class ToolResult {
  final String name;
  final bool success;
  final String? error;
  final dynamic result;
  ToolResult({required this.name, required this.success, this.error, this.result});
}