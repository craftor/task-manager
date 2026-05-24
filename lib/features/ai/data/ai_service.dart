import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models/chat_message.dart';
import '../../../core/services/ai_config_service.dart';

class AiService {
  final AiConfigService _config;

  AiService(this._config);

  Future<AIResponse> sendMessage(
    List<ChatMessage> history, {
    String? systemPrompt,
    String? appContext,
  }) async {
    final baseUrl = await _config.getBaseUrl();
    final apiKey = await _config.getApiKey();
    final model = await _config.getModelName();

    if (baseUrl == null || apiKey == null || model == null) {
      throw Exception('AI not configured. Please set API credentials in Settings.');
    }

    final base = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final messages = <Map<String, dynamic>>[];

    // Build system prompt with app context - ALWAYS send to keep AI grounded
    String fullSystemPrompt = systemPrompt ?? '';
    final contextBlock = '''
你是Task Manager App的AI助手，专门帮助用户管理任务、项目、心情、日记和特殊日期。

【你的职责】
- 回答用户关于App中数据和功能的问题
- 帮助创建、更新、删除任务和项目
- 记录心情和日记
- 管理特殊日期

【重要规则】
1. 回答必须基于用户提供的数据，不要编造不存在的信息
2. 如果用户问的问题在数据中找不到答案，明确告知用户
3. 如果需要执行操作（增删改），先征求用户确认
4. 保持回答简洁、友好

''';
    if (fullSystemPrompt.isNotEmpty) {
      fullSystemPrompt = '$contextBlock\n\n$fullSystemPrompt';
    } else {
      fullSystemPrompt = contextBlock;
    }

    // Append app context if available
    if (appContext != null && appContext.isNotEmpty) {
      fullSystemPrompt = '$fullSystemPrompt\n\n【当前App数据】\n$appContext';
    }

    if (fullSystemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': fullSystemPrompt});
    }
    for (final m in history) {
      final role = m.role == ChatRole.user
          ? 'user'
          : m.role == ChatRole.assistant
              ? 'assistant'
              : 'system';
      messages.add({'role': role, 'content': m.content});
    }

    final body = {
      'model': model,
      'messages': messages,
    };

    final response = await http.post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode != 200) {
      throw Exception('AI API error: ${response.statusCode} — ${response.body} — URL: $uri');
    }

    final data = json.decode(response.body);
    final choices = data['choices'] as List? ?? [];
    String text = '';

    for (final choice in choices) {
      final msg = choice['message'] as Map<String, dynamic>?;
      if (msg != null) {
        text = msg['content'] as String? ?? '';
        break;
      }
    }

    return AIResponse(content: text, toolCalls: []);
  }
}

class AIResponse {
  final String content;
  final List<ToolCall> toolCalls;
  AIResponse({required this.content, required this.toolCalls});
}