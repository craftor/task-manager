# AI Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AI assistant with floating button, bottom-sheet chat panel, user-configurable Anthropic-compatible model, tool calling for all CRUD operations, cloud-synced chat history.

**Architecture:** New `features/ai/` module with Riverpod state management, Supabase for chat history, Anthropic-compatible HTTP client for AI API calls. Settings stored in flutter_secure_storage. All existing CRUD operations are called via existing repositories.

**Tech Stack:** Riverpod, Drift (existing), Supabase (existing), flutter_secure_storage (existing), Anthropic SDK or HTTP client, TableCalendar bottom sheet pattern (existing in codebase)

---

## File Map

### New files to create:
- `lib/features/ai/domain/models/chat_message.dart` — ChatMessage entity
- `lib/features/ai/domain/repositories/chat_repository.dart` — Repository interface
- `lib/features/ai/data/chat_repository_impl.dart` — Supabase implementation
- `lib/features/ai/data/ai_service.dart` — Anthropic-compatible API client
- `lib/features/ai/presentation/providers/ai_provider.dart` — Riverpod provider for chat state
- `lib/features/ai/presentation/widgets/ai_floating_button.dart` — FAB at bottom-center
- `lib/features/ai/presentation/widgets/chat_message_bubble.dart` — Message bubble
- `lib/features/ai/presentation/screens/ai_chat_screen.dart` — Bottom sheet chat UI

### Existing files to modify:
- `lib/features/settings/presentation/screens/settings_screen.dart` — Add AI Settings navigation
- `lib/features/settings/data/` — Add AI config storage service (similar to secure_credentials_service)
- `lib/app.dart` — Add floating button overlay (or in MainScreen)
- `lib/features/settings/presentation/screens/` — New `ai_settings_screen.dart`
- `pubspec.yaml` — Add `http` package if needed
- Supabase schema: add `chat_messages` table

---

## Task 1: Supabase Schema — Add chat_messages table

**Files:**
- Modify: Supabase dashboard (SQL) or create migration script

- [ ] **Step 1: Document the SQL**

Add to `docs/supabase-schema.sql` or note for manual application:

```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  session_id UUID NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  tool_calls JSONB,
  tool_results JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_messages_owner" ON chat_messages
  FOR ALL USING (auth.uid() = user_id);
```

---

## Task 2: AI Config Storage Service

**Files:**
- Create: `lib/core/services/ai_config_service.dart`

- [ ] **Step 1: Write the service**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiConfigService {
  static const _storage = FlutterSecureStorage();
  static const _keyBaseUrl = 'ai_api_base_url';
  static const _keyApiKey = 'ai_api_key';
  static const _keyModelName = 'ai_model_name';

  Future<String?> getBaseUrl() => _storage.read(key: _keyBaseUrl);
  Future<void> setBaseUrl(String v) => _storage.write(key: _keyBaseUrl, value: v);

  Future<String?> getApiKey() => _storage.read(key: _keyApiKey);
  Future<void> setApiKey(String v) => _storage.write(key: _keyApiKey, value: v);

  Future<String?> getModelName() => _storage.read(key: _keyModelName);
  Future<void> setModelName(String v) => _storage.write(key: _keyModelName, value: v);

  Future<bool> isConfigured() async {
    final url = await getBaseUrl();
    final key = await getApiKey();
    final model = await getModelName();
    return url != null && key != null && model != null;
  }
}
```

- [ ] **Step 2: Export from core/services**

No barrel file exists, so just use the direct import.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/ai_config_service.dart
git commit -m "feat(ai): add AiConfigService for secure storage of AI credentials"
```

---

## Task 3: ChatMessage domain model

**Files:**
- Create: `lib/features/ai/domain/models/chat_message.dart`

- [ ] **Step 1: Write the model**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai/domain/models/chat_message.dart
git commit -m "feat(ai): add ChatMessage domain model"
```

---

## Task 4: ChatRepository interface and implementation

**Files:**
- Create: `lib/features/ai/domain/repositories/chat_repository.dart`
- Create: `lib/features/ai/data/chat_repository_impl.dart`

- [ ] **Step 1: Write the repository interface**

```dart
import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String sessionId);
  Future<void> saveMessage(ChatMessage msg);
  Future<String> createSession();
  Stream<List<ChatMessage>> watchMessages(String sessionId);
}
```

- [ ] **Step 2: Write the Supabase implementation**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

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
    // Session ID generated client-side, stored in messages
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/ai/domain/repositories/chat_repository.dart lib/features/ai/data/chat_repository_impl.dart
git commit -m "feat(ai): add ChatRepository with Supabase implementation"
```

---

## Task 5: AI Service — Anthropic-compatible API client

**Files:**
- Create: `lib/features/ai/data/ai_service.dart`

- [ ] **Step 1: Write the service**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models/chat_message.dart';
import '../../core/services/ai_config_service.dart';

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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai/data/ai_service.dart
git commit -m "feat(ai): add AiService with Anthropic-compatible API client and tool definitions"
```

---

## Task 6: AI Provider — Riverpod state management

**Files:**
- Create: `lib/features/ai/presentation/providers/ai_provider.dart`

- [ ] **Step 1: Write the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/ai_service.dart';
import '../../data/chat_repository_impl.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/services/ai_config_service.dart';
import '../../../supabase/supabase_client.dart';

final aiConfigServiceProvider = Provider((ref) => AiConfigService());

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(Supabase.instance.client);
});

final aiServiceProvider = Provider((ref) {
  return AiService(ref.watch(aiConfigServiceProvider));
});

final aiSessionIdProvider = StateProvider<String?>((ref) => null);

final aiMessagesProvider = StreamNotifierProvider<AiMessagesNotifier, List<ChatMessage>>(
  AiMessagesNotifier.new,
);

class AiMessagesNotifier extends StreamNotifier<List<ChatMessage>> {
  @override
  Stream<List<ChatMessage>> build() {
    final sessionId = ref.watch(aiSessionIdProvider);
    if (sessionId == null) return Stream.value([]);
    return ref.watch(chatRepositoryProvider).watchMessages(sessionId);
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(
    ref.watch(aiServiceProvider),
    ref.watch(chatRepositoryProvider),
    ref,
  );
});

class AiChatState {
  final bool isLoading;
  final String? error;
  final ToolCall? pendingToolCall;
  AiChatState({this.isLoading = false, this.error, this.pendingToolCall});
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiService _aiService;
  final ChatRepository _repository;
  final Ref _ref;

  AiChatNotifier(this._aiService, this._repository, this._ref) : super(AiChatState());

  Future<void> sendMessage(String text) async {
    final sessionId = _ref.read(aiSessionIdProvider);
    if (sessionId == null) return;

    state = AiChatState(isLoading: true);

    // Save user message
    await _repository.saveMessage(ChatMessage(
      id: const Uuid().v4(),
      sessionId: sessionId,
      role: ChatRole.user,
      content: text,
      createdAt: DateTime.now(),
    ));

    // Load full history
    final history = await _repository.getMessages(sessionId);

    try {
      final response = await _aiService.sendMessage(history);

      if (response.toolCalls.isNotEmpty) {
        // Show confirmation before executing
        state = AiChatState(
          pendingToolCall: response.toolCalls.first,
          isLoading: false,
        );
      } else {
        // Save AI response directly
        await _repository.saveMessage(ChatMessage(
          id: const Uuid().v4(),
          sessionId: sessionId,
          role: ChatRole.assistant,
          content: response.content,
          createdAt: DateTime.now(),
        ));
        state = AiChatState(isLoading: false);
      }
    } catch (e) {
      state = AiChatState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> confirmToolCall() async {
    final toolCall = state.pendingToolCall;
    if (toolCall == null) return;

    final sessionId = _ref.read(aiSessionIdProvider)!;

    // Execute the tool via the appropriate repository
    final result = await _executeTool(toolCall);

    // Save tool result as system message
    await _repository.saveMessage(ChatMessage(
      id: const Uuid().v4(),
      sessionId: sessionId,
      role: ChatRole.system,
      content: 'Tool ${toolCall.name} result: ${result.toString()}',
      toolResults: [
        ToolResult(name: toolCall.name, success: true, result: result),
      ],
      createdAt: DateTime.now(),
    ));

    // Send result back to AI for natural language response
    final history = await _repository.getMessages(sessionId);
    final response = await _aiService.sendMessage(history);

    await _repository.saveMessage(ChatMessage(
      id: const Uuid().v4(),
      sessionId: sessionId,
      role: ChatRole.assistant,
      content: response.content,
      createdAt: DateTime.now(),
    ));

    state = AiChatState(isLoading: false);
  }

  void cancelToolCall() {
    state = AiChatState(isLoading: false);
  }

  Future<dynamic> _executeTool(ToolCall toolCall) async {
    // Dispatch to existing repositories based on tool name
    switch (toolCall.name) {
      case 'create_task':
        final notifier = _ref.read(tasksProvider.notifier);
        await notifier.createTask(
          title: toolCall.arguments['title'] as String,
          projectId: toolCall.arguments['project_id'] as String?,
          description: toolCall.arguments['description'] as String? ?? '',
          dueDate: toolCall.arguments['due_date'] != null ? DateTime.tryParse(toolCall.arguments['due_date'] as String) : null,
        );
        return {'success': true};
      case 'add_mood':
        final service = MoodService();
        await service.setMoods(null, toolCall.arguments['date_key'] as String, List<String>.from(toolCall.arguments['emojis']));
        return {'success': true};
      default:
        return {'error': 'Unknown tool: ${toolCall.name}'};
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai/presentation/providers/ai_provider.dart
git commit -m "feat(ai): add AiChatNotifier with confirmation flow for tool calls"
```

---

## Task 7: ChatMessageBubble widget

**Files:**
- Create: `lib/features/ai/presentation/widgets/chat_message_bubble.dart`

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final isSystem = message.role == ChatRole.system;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isSystem
              ? AppColors.surfaceLight
              : isUser
                  ? AppColors.primary
                  : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: isSystem ? Border.all(color: AppColors.border) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔧 ${message.toolCalls!.first.name}\n${message.toolCalls!.first.arguments}',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai/presentation/widgets/chat_message_bubble.dart
git commit -m "feat(ai): add ChatMessageBubble widget"
```

---

## Task 8: AIFloatingButton widget

**Files:**
- Create: `lib/features/ai/presentation/widgets/ai_floating_button.dart`

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AiFloatingButton extends StatelessWidget {
  final VoidCallback onTap;
  const AiFloatingButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai/presentation/widgets/ai_floating_button.dart
git commit -m "feat(ai): add AiFloatingButton widget"
```

---

## Task 9: AI Chat Screen — Bottom Sheet

**Files:**
- Create: `lib/features/ai/presentation/screens/ai_chat_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/chat_message.dart';
import '../providers/ai_provider.dart';
import '../widgets/chat_message_bubble.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final messages = ref.watch(aiMessagesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('AI 助手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Messages
          Expanded(
            child: messages.when(
              data: (msgs) {
                if (msgs.isEmpty) {
                  return const Center(child: Text('开始对话吧！', style: TextStyle(color: AppColors.textMuted)));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => ChatMessageBubble(message: msgs[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
          // Tool confirmation
          if (chatState.pendingToolCall != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(children: [
                Expanded(
                  child: Text('确认执行 ${chatState.pendingToolCall!.name}？', style: const TextStyle(color: AppColors.textPrimary)),
                ),
                TextButton(onPressed: () => ref.read(aiChatProvider.notifier).cancelToolCall(), child: const Text('取消')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => ref.read(aiChatProvider.notifier).confirmToolCall(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('确认'),
                ),
              ]),
            ),
          // Error
          if (chatState.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(chatState.error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: chatState.isLoading ? null : _send,
                icon: chatState.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.send, color: AppColors.primary),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/ai/presentation/screens/ai_chat_screen.dart
git commit -m "feat(ai): add AiChatScreen bottom sheet UI"
```

---

## Task 10: Integrate floating button into MainScreen

**Files:**
- Modify: `lib/app.dart:MainScreen`

- [ ] **Step 1: Add imports and overlay**

Find the `MainScreen._buildSidebar()` method or the main scaffold. Add:

```dart
import 'features/ai/presentation/widgets/ai_floating_button.dart';
import 'features/ai/presentation/screens/ai_chat_screen.dart';
```

In the `build` method's `Scaffold`, add the `AiFloatingButton` as an `endDrawer` or `floatingActionButton`. Since we want it at bottom-center (not the default FAB corner), add it as an `Stack` overlay inside the `Scaffold.body`:

```dart
Stack(
  children: [
    // existing content (ListView or whatever body is)
    Positioned.fill(
      child: AiFloatingButton(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AiChatScreen(),
          );
        },
      ),
    ),
  ],
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/app.dart
git commit -m "feat(ai): integrate AiFloatingButton into MainScreen"
```

---

## Task 11: AI Settings screen

**Files:**
- Create: `lib/features/settings/presentation/screens/ai_settings_screen.dart`

- [ ] **Step 1: Write the settings screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/ai_config_service.dart';
import '../../../ai/presentation/providers/ai_provider.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = ref.read(aiConfigServiceProvider);
    _baseUrlController.text = await config.getBaseUrl() ?? '';
    _apiKeyController.text = await config.getApiKey() ?? '';
    _modelController.text = await config.getModelName() ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = ref.read(aiConfigServiceProvider);
    await config.setBaseUrl(_baseUrlController.text.trim());
    await config.setApiKey(_apiKeyController.text.trim());
    await config.setModelName(_modelController.text.trim());
    setState(() => _saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildField('API Base URL', _baseUrlController, 'https://api.siliconflow.cn/v1'),
          const SizedBox(height: 16),
          _buildField('API Key', _apiKeyController, '', obscure: true),
          const SizedBox(height: 16),
          _buildField('Model Name', _modelController, 'glm-4-flash'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: ctrl, obscureText: obscure, decoration: InputDecoration(hintText: hint, filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
      ],
    );
  }
}
```

- [ ] **Step 2: Add navigation from Settings screen**

Modify `lib/features/settings/presentation/screens/settings_screen.dart` to add a Settings tile:

```dart
ListTile(
  leading: const Icon(Icons.auto_awesome),
  title: const Text('AI 设置'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/presentation/screens/ai_settings_screen.dart lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(ai): add AI settings screen and navigation from Settings"
```

---

## Self-Review Checklist

- [ ] Spec coverage: All requirements from spec are covered by a task
- [ ] No placeholders: All steps have concrete code, no TBD/TODO
- [ ] Type consistency: ChatMessage, ToolCall, ToolResult names match across tasks
- [ ] Tool execution: `_executeTool` in ai_provider.dart dispatches to correct existing repository/method
- [ ] pubspec.yaml: May need `http` package for AI API calls — verify and add if missing
- [ ] Supabase schema: chat_messages table must be created before running

---

## Plan Summary

| Task | Description |
|------|-------------|
| 1 | Supabase chat_messages schema |
| 2 | AiConfigService |
| 3 | ChatMessage domain model |
| 4 | ChatRepository interface + impl |
| 5 | AiService with Anthropic-compatible API |
| 6 | AiProvider with tool call confirmation |
| 7 | ChatMessageBubble widget |
| 8 | AiFloatingButton widget |
| 9 | AiChatScreen bottom sheet |
| 10 | Integrate button into MainScreen |
| 11 | AI Settings screen + navigation |

---

## Next: Choose Execution Mode

**Plan complete and saved to `docs/superpowers/plans/2026-05-23-ai-assistant.md`. Two execution options:**

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans

Which approach?