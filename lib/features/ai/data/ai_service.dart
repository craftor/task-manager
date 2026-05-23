import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models/chat_message.dart';
import '../../../core/services/ai_config_service.dart';

class AiService {
  final AiConfigService _config;

  AiService(this._config);

  Future<AIResponse> sendMessage(List<ChatMessage> history, {String? systemPrompt}) async {
    final baseUrl = await _config.getBaseUrl();
    final apiKey = await _config.getApiKey();
    final model = await _config.getModelName();

    if (baseUrl == null || apiKey == null || model == null) {
      throw Exception('AI not configured. Please set API credentials in Settings.');
    }

    final uri = Uri.parse('$baseUrl/messages');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    };

    final messages = history.map((m) => {
      'role': m.role.name,
      'content': m.content,
    }).toList();

    final body = {
      'model': model,
      'max_tokens': 1024,
      'messages': messages,
      if (systemPrompt != null) 'system': systemPrompt,
      'tools': _availableTools,
    };

    final response = await http.post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode != 200) {
      throw Exception('AI API error: ${response.statusCode} — ${response.body}');
    }

    final data = json.decode(response.body);
    return AIResponse(
      content: data['content'][0]['text'],
      toolCalls: (data['content'] as List).where((b) => b['type'] == 'tool_use').map((b) => ToolCall(
        name: b['name'],
        arguments: Map<String, dynamic>.from(b['input']),
      )).toList(),
    );
  }

  static final _availableTools = [
    {
      'name': 'create_task',
      'description': 'Create a new task',
      'input_schema': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'project_id': {'type': 'string'},
          'priority': {'type': 'integer'},
          'due_date': {'type': 'string'},
          'description': {'type': 'string'},
        },
        'required': ['title'],
      },
    },
    {
      'name': 'update_task',
      'description': 'Update an existing task',
      'input_schema': {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'},
          'title': {'type': 'string'},
          'status': {'type': 'integer'},
          'priority': {'type': 'integer'},
        },
        'required': ['task_id'],
      },
    },
    {
      'name': 'delete_task',
      'description': 'Delete a task',
      'input_schema': {'type': 'object', 'properties': {'task_id': {'type': 'string'}}, 'required': ['task_id']},
    },
    {
      'name': 'create_project',
      'description': 'Create a new project',
      'input_schema': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'color': {'type': 'string'},
          'icon': {'type': 'string'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'add_mood',
      'description': 'Record mood for a date',
      'input_schema': {
        'type': 'object',
        'properties': {
          'date_key': {'type': 'string'},
          'emojis': {'type': 'array', 'items': {'type': 'string'}},
        },
        'required': ['date_key', 'emojis'],
      },
    },
    {
      'name': 'add_special_day',
      'description': 'Add a special day',
      'input_schema': {
        'type': 'object',
        'properties': {
          'date_key': {'type': 'string'},
          'color_index': {'type': 'integer'},
          'description': {'type': 'string'},
        },
        'required': ['date_key', 'color_index'],
      },
    },
    {
      'name': 'add_journal',
      'description': 'Write a journal entry',
      'input_schema': {
        'type': 'object',
        'properties': {
          'date_key': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['date_key', 'content'],
      },
    },
  ];
}

class AIResponse {
  final String content;
  final List<ToolCall> toolCalls;
  AIResponse({required this.content, required this.toolCalls});
}