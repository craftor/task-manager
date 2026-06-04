import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/time_entry.dart';
import 'remote_datasource.dart';

class SupabaseDatasource implements RemoteDatasource {
  final SupabaseClient _client;
  final String userId;

  SupabaseDatasource(this._client, this.userId);

  // Projects
  @override
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final response = await _client
        .from('projects')
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .order('created_at');
    return response;
  }

  @override
  Future<void> upsertProject(Project project, {DateTime? deletedAt}) async {
    final data = <String, dynamic>{
      'id': project.id,
      'user_id': userId,
      'parent_id': project.parentId,
      'name': project.name,
      'description': project.description,
      'color': project.color,
      'icon': project.icon,
      'start_date': project.startDate?.toIso8601String(),
      'end_date': project.endDate?.toIso8601String(),
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'sort_order': project.sortOrder,
      'is_default': project.isDefault,
    };
    if (deletedAt != null) {
      data['deleted_at'] = deletedAt.toIso8601String();
    }
    await _client.from('projects').upsert(data);
  }

  @override
  Future<void> deleteProject(String id) async {
    await _client.from('projects').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  // Tasks
  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .order('created_at');
    return response;
  }

  @override
  Future<void> upsertTask(Task task, {DateTime? deletedAt}) async {
    final data = <String, dynamic>{
      'id': task.id,
      'user_id': userId,
      'project_id': task.projectId,
      'title': task.title,
      'description': task.description,
      'priority': task.priority.index,
      'status': task.status.index,
      'start_date': task.startDate?.toIso8601String(),
      'due_date': task.dueDate?.toIso8601String(),
      'created_at': task.createdAt.toIso8601String(),
      'updated_at': task.updatedAt.toIso8601String(),
    };
    if (deletedAt != null) {
      data['deleted_at'] = deletedAt.toIso8601String();
    }
    await _client.from('tasks').upsert(data);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _client.from('tasks').update({
      'deleted_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', userId);
  }

  // Time Entries
  @override
  Future<List<Map<String, dynamic>>> fetchTimeEntries() async {
    final response = await _client
        .from('time_entries')
        .select()
        .eq('user_id', userId)
        .order('start_time');
    return response;
  }

  @override
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

  @override
  Future<void> deleteTimeEntry(String id) async {
    await _client.from('time_entries').delete().eq('id', id);
  }

  // Special Days
  @override
  Future<List<Map<String, dynamic>>> fetchSpecialDays() async {
    final response = await _client
        .from('special_days')
        .select()
        .eq('user_id', userId)
        .order('date_key');
    return response;
  }

  @override
  Future<void> upsertSpecialDay(String dateKey, String data) async {
    await _client.from('special_days').upsert({
      'id': '${userId}_$dateKey',
      'user_id': userId,
      'date_key': dateKey,
      'data': data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteSpecialDay(String dateKey) async {
    await _client
        .from('special_days')
        .delete()
        .eq('id', '${userId}_$dateKey');
  }

  // Moods
  @override
  Future<List<Map<String, dynamic>>> fetchMoods() async {
    final response = await _client
        .from('moods')
        .select()
        .eq('user_id', userId)
        .order('date_key');
    return response;
  }

  @override
  Future<void> upsertMood(String dateKey, String data) async {
    await _client.from('moods').upsert({
      'id': '${userId}_$dateKey',
      'user_id': userId,
      'date_key': dateKey,
      'data': data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteMood(String dateKey) async {
    await _client
        .from('moods')
        .delete()
        .eq('id', '${userId}_$dateKey');
  }

  // Journal Entries
  @override
  Future<List<Map<String, dynamic>>> fetchJournalEntries() async {
    final response = await _client
        .from('journal_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response;
  }

  @override
  Future<void> upsertJournalEntry(String dateKey, Map<String, dynamic> entry) async {
    await _client.from('journal_entries').upsert({
      'id': entry['id'],
      'user_id': userId,
      'date_key': dateKey,
      'content': entry['content'],
      'created_at': entry['created_at'],
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    await _client
        .from('journal_entries')
        .delete()
        .eq('id', entryId);
  }
}
