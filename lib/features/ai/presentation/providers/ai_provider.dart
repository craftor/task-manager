import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/ai_service.dart';
import '../../data/chat_repository_impl.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/services/ai_config_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../domain/entities/task.dart' show Priority, TaskStatus;
import '../../../mood/mood_provider.dart';
import '../../../tasks/presentation/providers/tasks_provider.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart';
import '../../../special_days/special_days_provider.dart';
import '../../../journal/journal_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _aiSessionIdKey = 'ai_session_id';

final aiConfigServiceProvider = Provider((ref) => AiConfigService());

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(Supabase.instance.client);
});

final aiServiceProvider = Provider((ref) {
  return AiService(ref.watch(aiConfigServiceProvider));
});

final aiSessionIdProvider = StateProvider<String?>((ref) {
  // Load persisted session ID on startup
  _loadPersistedSessionId().then((id) {
    if (id != null) {
      ref.read(_persistentSessionProvider.notifier).state = id;
    }
  });
  return null;
});

// Internal provider to hold persisted session across app restarts
final _persistentSessionProvider = StateProvider<String?>((ref) => null);

final aiMessagesListProvider = StateNotifierProvider<AiMessagesNotifier, List<ChatMessage>>((ref) {
  final sessionId = ref.watch(aiSessionIdProvider);
  return AiMessagesNotifier(ref, sessionId);
});

Future<String?> _loadPersistedSessionId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiSessionIdKey);
  } catch (_) {
    return null;
  }
}

Future<void> _persistSessionId(String sessionId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiSessionIdKey, sessionId);
  } catch (_) {}
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(
    ref.watch(aiServiceProvider),
    ref.watch(chatRepositoryProvider),
    ref,
  );
});

class AiMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  final String? _sessionId;

  AiMessagesNotifier(this._ref, this._sessionId) : super([]) {
    if (_sessionId != null) _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (_sessionId == null) return;
    try {
      final repo = _ref.read(chatRepositoryProvider);
      final msgs = await repo.getMessages(_sessionId!);
      state = msgs;
      Logger.d('AiMessagesNotifier: loaded ${msgs.length} messages');
    } catch (e) {
      Logger.e('AiMessagesNotifier._loadMessages failed', error: e);
    }
  }

  Future<void> refresh() async {
    await _loadMessages();
  }

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
  }
}

class ParsedAction {
  final String action;
  final Map<String, dynamic> params;
  ParsedAction({required this.action, required this.params});
}

class AiChatState {
  final bool isLoading;
  final String? error;
  final ParsedAction? pendingAction;
  AiChatState({this.isLoading = false, this.error, this.pendingAction});
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiService _aiService;
  final ChatRepository _repository;
  final Ref _ref;

  AiChatNotifier(this._aiService, this._repository, this._ref) : super(AiChatState());

  Future<void> sendMessage(String text) async {
    var sessionId = _ref.read(aiSessionIdProvider);
    if (sessionId == null) {
      sessionId = const Uuid().v4();
      _ref.read(aiSessionIdProvider.notifier).state = sessionId;
      SharedPreferences.getInstance().then((prefs) => prefs.setString('ai_session_id', sessionId!));
    }

    if (sessionId == null) {
      state = AiChatState(error: 'Session not initialized');
      return;
    }

    state = AiChatState(isLoading: true);

    try {
      final userMsg = ChatMessage(
        id: const Uuid().v4(),
        sessionId: sessionId,
        role: ChatRole.user,
        content: text,
        createdAt: DateTime.now(),
      );
      await _repository.saveMessage(userMsg);
      _ref.read(aiMessagesListProvider.notifier).addMessage(userMsg);

      final history = await _repository.getMessages(sessionId);
      Logger.d('AiChatNotifier: history has ${history.length} messages');

      // Fetch current app data to provide context to AI
      final appContext = await _buildAppContext();
      Logger.d('AiChatNotifier: app context fetched');

      final response = await _aiService.sendMessage(history, appContext: appContext);
      final cleanContent = _stripThinkTags(response.content);
      Logger.d('AiChatNotifier: AI response: "$cleanContent"');

      // Check if response contains an action tag
      final parsed = _parseAction(cleanContent);
      if (parsed != null) {
        // Save AI response with action tag visible to user
        await _repository.saveMessage(ChatMessage(
          id: const Uuid().v4(),
          sessionId: sessionId,
          role: ChatRole.assistant,
          content: cleanContent,
          createdAt: DateTime.now(),
        ));
        _ref.read(aiMessagesListProvider.notifier).addMessage(ChatMessage(
          id: const Uuid().v4(),
          sessionId: sessionId,
          role: ChatRole.assistant,
          content: cleanContent,
          createdAt: DateTime.now(),
        ));
        state = AiChatState(pendingAction: parsed, isLoading: false);
      } else {
        // Just a normal text response
        await _repository.saveMessage(ChatMessage(
          id: const Uuid().v4(),
          sessionId: sessionId,
          role: ChatRole.assistant,
          content: cleanContent,
          createdAt: DateTime.now(),
        ));
        _ref.read(aiMessagesListProvider.notifier).addMessage(ChatMessage(
          id: const Uuid().v4(),
          sessionId: sessionId,
          role: ChatRole.assistant,
          content: cleanContent,
          createdAt: DateTime.now(),
        ));
        state = AiChatState(isLoading: false);
      }
    } catch (e, st) {
      Logger.e('AiChatNotifier.sendMessage failed', error: e, stackTrace: st);
      state = AiChatState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> confirmAction() async {
    final action = state.pendingAction;
    if (action == null) return;

    final sessionId = _ref.read(aiSessionIdProvider)!;

    try {
      final result = await _executeAction(action);

      await _repository.saveMessage(ChatMessage(
        id: const Uuid().v4(),
        sessionId: sessionId,
        role: ChatRole.system,
        content: 'Action ${action.action} result: $result',
        createdAt: DateTime.now(),
      ));
      _ref.read(aiMessagesListProvider.notifier).addMessage(ChatMessage(
        id: const Uuid().v4(),
        sessionId: sessionId,
        role: ChatRole.system,
        content: '${action.action} 执行成功',
        createdAt: DateTime.now(),
      ));
      state = AiChatState(isLoading: false);
    } catch (e) {
      await _repository.saveMessage(ChatMessage(
        id: const Uuid().v4(),
        sessionId: sessionId,
        role: ChatRole.system,
        content: 'Action ${action.action} failed: $e',
        createdAt: DateTime.now(),
      ));
      state = AiChatState(error: e.toString(), isLoading: false);
    }
  }

  void cancelAction() {
    state = AiChatState(isLoading: false);
  }

  String _stripThinkTags(String text) {
    // Remove <think>... blocks and the newlines that follow
    final result = text.replaceAll(RegExp(r'<think>[\s\S]*?\s*'), '');
    return result.trim();
  }

  static final _actionPattern = RegExp(r'\[ACTION\]\s*(\w+)\s*(.*)', dotAll: true);

  ParsedAction? _parseAction(String text) {
    final match = _actionPattern.firstMatch(text);
    if (match == null) return null;
    final action = match.group(1)!;
    final paramsStr = match.group(2)?.trim() ?? '{}';
    try {
      Map<String, dynamic> params = {};
      // Try JSON first
      if (paramsStr.startsWith('{')) {
        params = Map<String, dynamic>.from(
          const JsonDecoder().convert(paramsStr) as Map,
        );
      } else {
        // Parse key=value pairs: title=完成任务, priority=2
        for (final part in paramsStr.split(',')) {
          final kv = part.split('=');
          if (kv.length == 2) {
            final key = kv[0].trim();
            final value = kv[1].trim();
            params[key] = int.tryParse(value) ?? double.tryParse(value) ?? value;
          }
        }
      }
      return ParsedAction(action: action, params: params);
    } catch (e) {
      Logger.e('Failed to parse action params: $paramsStr', error: e);
      return null;
    }
  }

  Future<dynamic> _executeAction(ParsedAction action) async {
    switch (action.action) {
      case 'create_task':
        final notifier = _ref.read(tasksProvider.notifier);
        await notifier.createTask(
          title: action.params['title'] as String? ?? '',
          projectId: action.params['project_id'] as String? ?? '',
          description: action.params['description'] as String? ?? '',
          dueDate: action.params['due_date'] != null ? DateTime.tryParse(action.params['due_date'] as String) : null,
        );
        return {'success': true, 'action': 'create_task'};
      case 'update_task':
        final notifier = _ref.read(tasksProvider.notifier);
        final taskId = action.params['task_id'] as String;
        final taskRepo = _ref.read(taskRepositoryProvider);
        final task = await taskRepo.getTaskById(taskId);
        if (task == null) return {'error': 'Task not found: $taskId'};
        final updatedTask = task.copyWith(
          title: action.params['title'] as String? ?? task.title,
          status: action.params['status'] != null ? TaskStatus.values[action.params['status'] as int] : task.status,
          priority: action.params['priority'] != null ? Priority.values[action.params['priority'] as int] : task.priority,
          updatedAt: DateTime.now(),
        );
        await notifier.updateTask(updatedTask);
        return {'success': true, 'action': 'update_task'};
      case 'delete_task':
        final notifier = _ref.read(tasksProvider.notifier);
        await notifier.deleteTask(action.params['task_id'] as String);
        return {'success': true, 'action': 'delete_task'};
      case 'create_project':
        final notifier = _ref.read(projectsProvider.notifier);
        await notifier.createProject(
          name: action.params['name'] as String? ?? '',
          color: action.params['color'] as String? ?? '#00ff9f',
          icon: action.params['icon'] as String? ?? '📁',
        );
        return {'success': true, 'action': 'create_project'};
      case 'add_mood':
        final remote = _ref.read(supabaseDatasourceProvider);
        if (remote == null) return {'error': 'Not signed in'};
        final service = _ref.read(moodServiceProvider);
        await service.setMoods(
          remote,
          action.params['date_key'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
          (action.params['emojis'] as String?)?.split(',') ?? (action.params['emojis'] as List?)?.cast<String>() ?? [],
        );
        return {'success': true, 'action': 'add_mood'};
      case 'add_special_day':
        final remote = _ref.read(supabaseDatasourceProvider);
        if (remote == null) return {'error': 'Not signed in'};
        final service = _ref.read(specialDaysServiceProvider);
        await service.setDay(
          remote,
          action.params['date_key'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
          action.params['color_index'] as int? ?? 0,
          action.params['description'] as String?,
        );
        return {'success': true, 'action': 'add_special_day'};
      case 'add_journal':
        final remote = _ref.read(supabaseDatasourceProvider);
        if (remote == null) return {'error': 'Not signed in'};
        final service = _ref.read(journalServiceProvider);
        await service.addEntry(
          remote,
          action.params['date_key'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
          action.params['content'] as String? ?? '',
        );
        return {'success': true, 'action': 'add_journal'};
      case 'get_today_tasks':
        final tasks = await _ref.read(tasksProvider.future);
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final todayTasks = tasks.where((t) => t.dueDate?.toIso8601String().substring(0, 10) == today).toList();
        return {'count': todayTasks.length, 'tasks': todayTasks.map((t) => t.title).toList()};
      default:
        return {'error': 'Unknown action: ${action.action}'};
    }
  }

  Future<String> _buildAppContext() async {
    final buffer = StringBuffer();

    // Projects
    try {
      final projects = await _ref.read(projectsProvider.future);
      buffer.writeln('【项目列表】(${projects.length}个)');
      for (final p in projects.take(20)) {
        buffer.writeln('- ${p.name} (id: ${p.id}, color: ${p.color})');
      }
      if (projects.length > 20) buffer.writeln('... 还有${projects.length - 20}个');
    } catch (e) {
      buffer.writeln('【项目列表】获取失败: $e');
    }

    // Tasks
    try {
      final tasks = await _ref.read(tasksProvider.future);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      buffer.writeln('\n【任务列表】(共${tasks.length}个)');

      // Overdue
      final overdue = tasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(today) && t.status != TaskStatus.completed).toList();
      if (overdue.isNotEmpty) {
        buffer.writeln('- 已过期(${overdue.length}个): ${overdue.map((t) => t.title).take(5).join(', ')}${overdue.length > 5 ? '...' : ''}');
      }

      // Today
      final todayTasks = tasks.where((t) => t.dueDate != null && t.dueDate!.year == today.year && t.dueDate!.month == today.month && t.dueDate!.day == today.day).toList();
      if (todayTasks.isNotEmpty) {
        buffer.writeln('- 今天(${todayTasks.length}个): ${todayTasks.map((t) => t.title).take(5).join(', ')}${todayTasks.length > 5 ? '...' : ''}');
      }

      // This week
      final weekTasks = tasks.where((t) => t.dueDate != null && !t.dueDate!.isBefore(weekStart) && !t.dueDate!.isAfter(weekEnd) && t.dueDate!.day != today.day).toList();
      if (weekTasks.isNotEmpty) {
        buffer.writeln('- 本周(${weekTasks.length}个): ${weekTasks.map((t) => t.title).take(5).join(', ')}${weekTasks.length > 5 ? '...' : ''}');
      }

      // No date
      final noDate = tasks.where((t) => t.dueDate == null).toList();
      if (noDate.isNotEmpty) {
        buffer.writeln('- 无截止日期(${noDate.length}个): ${noDate.map((t) => t.title).take(5).join(', ')}${noDate.length > 5 ? '...' : ''}');
      }

      // Completed
      final completed = tasks.where((t) => t.status == TaskStatus.completed).toList();
      if (completed.isNotEmpty) {
        buffer.writeln('- 已完成(${completed.length}个)');
      }
    } catch (e) {
      buffer.writeln('\n【任务列表】获取失败: $e');
    }

    // Moods (last 7 days)
    try {
      final moodService = _ref.read(moodServiceProvider);
      final moods = await moodService.getAllMoods();
      final now = DateTime.now();
      buffer.writeln('\n【最近心情】(最近7天)');
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final emojis = moods[key];
        if (emojis != null && emojis.isNotEmpty) {
          buffer.writeln('- $key: ${emojis.join(' ')}');
        }
      }
    } catch (e) {
      buffer.writeln('\n【最近心情】获取失败: $e');
    }

    // Special days
    try {
      final specialDaysService = _ref.read(specialDaysServiceProvider);
      final remote = _ref.read(supabaseDatasourceProvider);
      final specialDays = await specialDaysService.getAll(remote);
      if (specialDays.isNotEmpty) {
        buffer.writeln('\n【特殊日子】(${specialDays.length}个)');
        final sorted = specialDays.keys.toList()..sort();
        for (final key in sorted.take(10)) {
          final data = specialDays[key]!;
          buffer.writeln('- $key: color=${data['color'] ?? '0'}, desc=${data['desc'] ?? ''}');
        }
        if (sorted.length > 10) buffer.writeln('... 还有${sorted.length - 10}个');
      }
    } catch (e) {
      buffer.writeln('\n【特殊日子】获取失败: $e');
    }

    // Journal (last 3 entries)
    try {
      final journalService = _ref.read(journalServiceProvider);
      final dates = await journalService.getAllDates();
      if (dates.isNotEmpty) {
        buffer.writeln('\n【最近日记】(最近3篇)');
        final sortedDates = dates..sort((a, b) => b.compareTo(a));
        for (final dateKey in sortedDates.take(3)) {
          final entries = await journalService.getEntries(dateKey);
          if (entries.isNotEmpty) {
            buffer.writeln('- $dateKey: ${entries.first.content.length > 50 ? '${entries.first.content.substring(0, 50)}...' : entries.first.content}');
          }
        }
      }
    } catch (e) {
      buffer.writeln('\n【最近日记】获取失败: $e');
    }

    return buffer.toString();
  }
}

