import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/ai_service.dart';
import '../../data/chat_repository_impl.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/services/ai_config_service.dart';
import '../../../mood/mood_provider.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          projectId: toolCall.arguments['project_id'] as String? ?? '',
          description: toolCall.arguments['description'] as String? ?? '',
          dueDate: toolCall.arguments['due_date'] != null ? DateTime.tryParse(toolCall.arguments['due_date'] as String) : null,
        );
        return {'success': true};
      case 'add_mood':
        final remote = _ref.read(supabaseDatasourceProvider);
        if (remote == null) return {'error': 'Not signed in'};
        final service = _ref.read(moodServiceProvider);
        await service.setMoods(remote, toolCall.arguments['date_key'] as String, List<String>.from(toolCall.arguments['emojis']));
        return {'success': true};
      default:
        return {'error': 'Not implemented'};
    }
  }
}