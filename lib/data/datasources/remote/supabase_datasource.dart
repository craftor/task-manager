import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/time_entry.dart';

class SupabaseDatasource {
  final SupabaseClient _client;
  final String userId;

  SupabaseDatasource(this._client, this.userId);

  // Projects
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final response = await _client
        .from('projects')
        .select()
        .eq('user_id', userId)
        .is_('deleted_at', null)
        .order('created_at');
    return response;
  }

  Future<void> upsertProject(Project project) async {
    await _client.from('projects').upsert({
      'id': project.id,
      'user_id': userId,
      'parent_id': project.parentId,
      'name': project.name,
      'color': project.color,
      'icon': project.icon,
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteProject(String id) async {
    await _client.from('projects').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // Tasks
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .is_('deleted_at', null)
        .order('created_at');
    return response;
  }

  Future<void> upsertTask(Task task) async {
    await _client.from('tasks').upsert({
      'id': task.id,
      'user_id': userId,
      'project_id': task.projectId,
      'parent_task_id': task.parentTaskId,
      'title': task.title,
      'description': task.description,
      'priority': task.priority.index,
      'status': task.status.index,
      'due_date': task.dueDate?.toIso8601String(),
      'tags': task.tags.join(','),
      'estimated_minutes': task.estimatedMinutes,
      'actual_minutes': task.actualMinutes,
      'is_recurring': task.isRecurring,
      'recurring_rule': task.recurringRule,
      'created_at': task.createdAt.toIso8601String(),
      'updated_at': task.updatedAt.toIso8601String(),
    });
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // Time Entries
  Future<List<Map<String, dynamic>>> fetchTimeEntries() async {
    final response = await _client
        .from('time_entries')
        .select()
        .eq('user_id', userId)
        .order('start_time');
    return response;
  }

  Future<void> upsertTimeEntry(TimeEntry entry) async {
    await _client.from('time_entries').upsert({
      'id': entry.id,
      'user_id': userId,
      'task_id': entry.taskId,
      'start_time': entry.startTime.toIso8601String(),
      'end_time': entry.endTime?.toIso8601String(),
      'duration_minutes': entry.durationMinutes,
      'note': entry.note,
      'manual': entry.manual,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteTimeEntry(String id) async {
    await _client.from('time_entries').delete().eq('id', id);
  }
}