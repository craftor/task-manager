// ignore_for_file: deprecated_member_use
// All `Databases` methods (createDocument / updateDocument / deleteDocument /
// listDocuments) are deprecated in Appwrite SDK 1.8.0 in favor of
// `TablesDB`. SDK 21.4.0 still ships the deprecated surface, so we use it.

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/time_entry.dart';
import 'remote_datasource.dart';

/// Appwrite implementation of [RemoteDatasource].
///
/// All methods are now implemented for the 6 collections:
/// - projects (C.1)
/// - tasks (C.2) — also closes the 7-field gap left by SupabaseDatasource
/// - time_entries (C.3)
/// - special_days + moods (C.4)
/// - journal_entries (C.5)
///
/// Appwrite auto-manages `$createdAt` / `$updatedAt` on every document —
/// they are never sent in the payload. On read, we project them into the
/// row map as `created_at` / `updated_at` (ISO 8601) so the local Drift
/// schema is satisfied.
///
/// All queries include `Query.equal('user_id', userId)` because Appwrite
/// self-hosted has no native row-level RLS — every collection permission
/// is set to "User" with full CRUD in the console.
class AppwriteDatasource implements RemoteDatasource {
  final Client _client;
  final String userId;
  final String databaseId;

  AppwriteDatasource(this._client, this.userId, this.databaseId);

  Databases get _databases => Databases(_client);

  // ─── Shared upsert helper ────────────────────────────────────────────

  /// Appwrite has no native upsert. Try create; on 409 (document already
  /// exists) fall back to update. Any other Appwrite error rethrows.
  Future<void> _upsertDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _databases.createDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: documentId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: collectionId,
          documentId: documentId,
          data: data,
        );
      } else {
        rethrow;
      }
    }
  }

  // ─── Projects (C.1) ─────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'projects',
      queries: [
        Query.equal('user_id', userId),
        Query.isNull('deleted_at'),
        Query.orderAsc(r'$createdAt'),
      ],
    );
    return result.documents.map(_docToRow).toList();
  }

  @override
  Future<void> upsertProject(Project project, {DateTime? deletedAt}) async {
    await _upsertDocument(
      collectionId: 'projects',
      documentId: project.id,
      data: _projectPayload(project, deletedAt: deletedAt),
    );
  }

  @override
  Future<void> deleteProject(String id) async {
    await _databases.updateDocument(
      databaseId: databaseId,
      collectionId: 'projects',
      documentId: id,
      data: {'deleted_at': DateTime.now().toIso8601String()},
    );
  }

  Map<String, dynamic> _projectPayload(Project project, {DateTime? deletedAt}) {
    final data = <String, dynamic>{
      'user_id': userId,
      'parent_id': project.parentId,
      'name': project.name,
      'description': project.description,
      'color': project.color,
      'icon': project.icon,
      'start_date': project.startDate?.toIso8601String(),
      'end_date': project.endDate?.toIso8601String(),
      'sort_order': project.sortOrder,
      'is_default': project.isDefault,
    };
    if (deletedAt != null) {
      data['deleted_at'] = deletedAt.toIso8601String();
    }
    return data;
  }

  // ─── Tasks (C.2) — closes the 7-field gap ───────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'tasks',
      queries: [
        Query.equal('user_id', userId),
        Query.isNull('deleted_at'),
        Query.orderAsc(r'$createdAt'),
      ],
    );
    return result.documents.map(_docToRow).toList();
  }

  @override
  Future<void> upsertTask(Task task, {DateTime? deletedAt}) async {
    await _upsertDocument(
      collectionId: 'tasks',
      documentId: task.id,
      data: _taskPayload(task, deletedAt: deletedAt),
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    await _databases.updateDocument(
      databaseId: databaseId,
      collectionId: 'tasks',
      documentId: id,
      data: {'deleted_at': DateTime.now().toIso8601String()},
    );
  }

  Map<String, dynamic> _taskPayload(Task task, {DateTime? deletedAt}) {
    final data = <String, dynamic>{
      'user_id': userId,
      'project_id': task.projectId,
      'parent_task_id': task.parentTaskId,
      'title': task.title,
      'description': task.description,
      'priority': task.priority.index,
      'status': task.status.index,
      'start_date': task.startDate?.toIso8601String(),
      'due_date': task.dueDate?.toIso8601String(),
      'tags': task.tags,
      'estimated_minutes': task.estimatedMinutes,
      'actual_minutes': task.actualMinutes,
      'is_recurring': task.isRecurring,
      'recurring_rule': task.recurringRule,
      'sort_order': task.sortOrder,
    };
    if (deletedAt != null) {
      data['deleted_at'] = deletedAt.toIso8601String();
    }
    return data;
  }

  // ─── Time Entries (C.3) — hard delete on deleteTimeEntry ──────────

  @override
  Future<List<Map<String, dynamic>>> fetchTimeEntries() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'time_entries',
      queries: [
        Query.equal('user_id', userId),
        Query.orderAsc('start_time'),
      ],
    );
    return result.documents.map(_docToRow).toList();
  }

  @override
  Future<void> upsertTimeEntry(TimeEntry entry) async {
    await _upsertDocument(
      collectionId: 'time_entries',
      documentId: entry.id,
      data: {
        'user_id': userId,
        'task_id': entry.taskId,
        'start_time': entry.startTime.toIso8601String(),
        'end_time': entry.endTime?.toIso8601String(),
        'duration_minutes': entry.durationMinutes,
        'note': entry.note,
        'manual': entry.manual,
      },
    );
  }

  @override
  Future<void> deleteTimeEntry(String id) async {
    await _databases.deleteDocument(
      databaseId: databaseId,
      collectionId: 'time_entries',
      documentId: id,
    );
  }

  // ─── Special Days (C.4) — composite id = userId_dateKey ────────────

  @override
  Future<List<Map<String, dynamic>>> fetchSpecialDays() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'special_days',
      queries: [
        Query.equal('user_id', userId),
        Query.orderAsc('date_key'),
      ],
    );
    return result.documents.map(_docToRow).toList();
  }

  @override
  Future<void> upsertSpecialDay(String dateKey, String data) async {
    await _upsertDocument(
      collectionId: 'special_days',
      documentId: _compositeId(dateKey),
      data: {
        'user_id': userId,
        'date_key': dateKey,
        'data': data,
      },
    );
  }

  @override
  Future<void> deleteSpecialDay(String dateKey) async {
    await _databases.deleteDocument(
      databaseId: databaseId,
      collectionId: 'special_days',
      documentId: _compositeId(dateKey),
    );
  }

  // ─── Moods (C.4) — same shape as special_days ──────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchMoods() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'moods',
      queries: [
        Query.equal('user_id', userId),
        Query.orderAsc('date_key'),
      ],
    );
    return result.documents.map(_docToRow).toList();
  }

  @override
  Future<void> upsertMood(String dateKey, String data) async {
    await _upsertDocument(
      collectionId: 'moods',
      documentId: _compositeId(dateKey),
      data: {
        'user_id': userId,
        'date_key': dateKey,
        'data': data,
      },
    );
  }

  @override
  Future<void> deleteMood(String dateKey) async {
    await _databases.deleteDocument(
      databaseId: databaseId,
      collectionId: 'moods',
      documentId: _compositeId(dateKey),
    );
  }

  // ─── Journal Entries (C.5) — hard delete ────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchJournalEntries() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'journal_entries',
      queries: [
        Query.equal('user_id', userId),
        Query.orderDesc(r'$createdAt'),
      ],
    );
    return result.documents.map(_docToRow).toList();
  }

  @override
  Future<void> upsertJournalEntry(
      String dateKey, Map<String, dynamic> entry) async {
    await _upsertDocument(
      collectionId: 'journal_entries',
      documentId: entry['id'] as String,
      data: {
        'user_id': userId,
        'date_key': dateKey,
        'content': entry['content'],
      },
    );
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    await _databases.deleteDocument(
      databaseId: databaseId,
      collectionId: 'journal_entries',
      documentId: entryId,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  /// Project an Appwrite `Document` back to the row shape downstream
  /// repositories expect: snake_case fields, `id` set, `created_at` /
  /// `updated_at` populated from the auto-managed `$createdAt` /
  /// `$updatedAt` (which are already ISO 8601 strings in SDK 21.4.0).
  Map<String, dynamic> _docToRow(Document doc) {
    final data = Map<String, dynamic>.from(doc.data);
    data['id'] = doc.$id;
    data['created_at'] = doc.$createdAt;
    data['updated_at'] = doc.$updatedAt;
    return data;
  }

  /// Composite document id for special_days and moods (one row per
  /// user × date). Matches the Supabase convention.
  String _compositeId(String dateKey) => '${userId}_$dateKey';
}
