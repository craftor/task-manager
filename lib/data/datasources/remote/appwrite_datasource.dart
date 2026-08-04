import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
// HttpMethod is not re-exported by appwrite.dart (SDK 21.4.0, pinned).
// ignore: implementation_imports
import 'package:appwrite/src/enums.dart' show HttpMethod;
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/time_entry.dart';
import 'remote_datasource.dart';
import 'user_scoped_query.dart';

/// Appwrite implementation of [RemoteDatasource], using the `TablesDB`
/// service (SDK 21.4.0's recommended replacement for the deprecated
/// `Databases` API).
///
/// All methods cover the 6 collections (now addressed as tables):
/// - projects (C.1)
/// - tasks (C.2) — also closes the 7-field gap left by SupabaseDatasource
/// - time_entries (C.3)
/// - special_days + moods (C.4)
/// - journal_entries (C.5)
///
/// Appwrite auto-manages `$createdAt` / `$updatedAt` on every row —
/// they are never sent in the payload. On read, we project them into
/// the row map as `created_at` / `updated_at` (ISO 8601) so the local
/// Drift schema is satisfied.
///
/// All queries include `Query.equal('user_id', userId)` because Appwrite
/// self-hosted has no native row-level RLS — every collection permission
/// is set to "User" with full CRUD in the console.
class AppwriteDatasource implements RemoteDatasource {
  final Client _client;
  final String userId;
  final String databaseId;

  AppwriteDatasource(this._client, this.userId, this.databaseId);

  TablesDB get _tablesDB => TablesDB(_client);

  /// Exposed for `SyncManager`'s Realtime subscription. Shares the same
  /// authenticated `Client` instance used for REST calls (so the
  /// WebSocket upgrade carries the session cookie).
  Realtime get realtime => Realtime(_client);

  static const int _pageSize = 100;

  // ─── Shared fetch helpers (paginated) ────────────────────────────────

  /// Fetch ALL rows of [tableId] through the SDK's `Row` model, paging
  /// with limit/offset. (Appwrite caps a single listRows call at 25
  /// rows by default.)
  Future<List<Map<String, dynamic>>> _fetchAllRows(
    String tableId,
    List<String> baseQueries,
  ) async {
    final out = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final result = await _tablesDB.listRows(
        databaseId: databaseId,
        tableId: tableId,
        queries: [...baseQueries, Query.limit(_pageSize), Query.offset(offset)],
      );
      out.addAll(result.rows.map(_rowToMap));
      if (result.rows.isEmpty || out.length >= result.total) break;
      offset += _pageSize;
    }
    return out;
  }

  /// Raw fetch that bypasses the SDK's `Row` model. SDK 21.4.0's
  /// `Row.fromMap` does `data: map["data"] ?? map`, so a row with a
  /// custom attribute literally named `data` (special_days, moods)
  /// deserializes with `Row.data` set to that attribute's raw value —
  /// losing all sibling attributes and throwing
  /// `type 'String' is not a subtype of type 'Map<String, dynamic>'` in
  /// [_rowToMap]. Calling the REST endpoint directly avoids that.
  Future<List<Map<String, dynamic>>> _fetchRaw(
    String tableId,
    List<String> baseQueries,
  ) async {
    final out = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final res = await _client.call(
        HttpMethod.get,
        path: '/tablesdb/$databaseId/tables/$tableId/rows',
        params: {
          'queries': [...baseQueries, Query.limit(_pageSize), Query.offset(offset)],
        },
      );
      final total = res.data['total'] as int;
      final rows = (res.data['rows'] as List).cast<Map<String, dynamic>>();
      for (final row in rows) {
        final r = Map<String, dynamic>.from(row);
        r['id'] = row[r'$id'];
        r['created_at'] = row[r'$createdAt'];
        r['updated_at'] = row[r'$updatedAt'];
        out.add(r);
      }
      if (rows.isEmpty || out.length >= total) break;
      offset += _pageSize;
    }
    return out;
  }

  // ─── Shared upsert helper ────────────────────────────────────────────

  /// SDK 21.4.0's `TablesDB.upsertRow` is a single round-trip native
  /// upsert — no try/catch, no 409 probing.
  Future<void> _upsertRow({
    required String tableId,
    required String rowId,
    required Map<String, dynamic> data,
  }) {
    return _tablesDB.upsertRow(
      databaseId: databaseId,
      tableId: tableId,
      rowId: rowId,
      data: data,
    );
  }

  // ─── Projects (C.1) ─────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchProjects() =>
      _fetchAllRows('projects', buildLiveUserScopedQueries(userId));

  @override
  Future<void> upsertProject(Project project, {DateTime? deletedAt}) async {
    await _upsertRow(
      tableId: 'projects',
      rowId: project.id,
      data: _projectPayload(project, deletedAt: deletedAt),
    );
  }

  @override
  Future<void> deleteProject(String id, {DateTime? deletedAt}) async {
    await _tablesDB.updateRow(
      databaseId: databaseId,
      tableId: 'projects',
      rowId: id,
      data: {'deleted_at': (deletedAt ?? DateTime.now()).toIso8601String()},
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
  Future<List<Map<String, dynamic>>> fetchTasks() =>
      _fetchAllRows('tasks', buildLiveUserScopedQueries(userId));

  @override
  Future<void> upsertTask(Task task, {DateTime? deletedAt}) async {
    await _upsertRow(
      tableId: 'tasks',
      rowId: task.id,
      data: _taskPayload(task, deletedAt: deletedAt),
    );
  }

  @override
  Future<void> deleteTask(String id, {DateTime? deletedAt}) async {
    await _tablesDB.updateRow(
      databaseId: databaseId,
      tableId: 'tasks',
      rowId: id,
      data: {'deleted_at': (deletedAt ?? DateTime.now()).toIso8601String()},
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
  Future<List<Map<String, dynamic>>> fetchTimeEntries() => _fetchAllRows(
      'time_entries',
      buildUserScopedQueries(userId, orderBy: Query.orderAsc('start_time')));

  @override
  Future<void> upsertTimeEntry(TimeEntry entry) async {
    await _upsertRow(
      tableId: 'time_entries',
      rowId: entry.id,
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
    await _tablesDB.deleteRow(
      databaseId: databaseId,
      tableId: 'time_entries',
      rowId: id,
    );
  }

  // ─── Special Days (C.4) — composite id = userId_dateKey ────────────

  @override
  // Raw path: this collection has a custom attribute literally named
  // 'data' — see [_fetchRaw] for why the Row model can't parse it.
  Future<List<Map<String, dynamic>>> fetchSpecialDays() => _fetchRaw(
      'special_days',
      buildUserScopedQueries(userId, orderBy: Query.orderAsc('date_key')));

  @override
  Future<void> upsertSpecialDay(String dateKey, String data) async {
    await _upsertRow(
      tableId: 'special_days',
      rowId: _compositeId(dateKey),
      data: {
        'user_id': userId,
        'date_key': dateKey,
        'data': data,
      },
    );
  }

  @override
  Future<void> deleteSpecialDay(String dateKey) async {
    await _tablesDB.deleteRow(
      databaseId: databaseId,
      tableId: 'special_days',
      rowId: _compositeId(dateKey),
    );
  }

  // ─── Moods (C.4) — same shape as special_days ──────────────────────

  @override
  // Raw path: same 'data'-attribute hazard as special_days — see [_fetchRaw].
  Future<List<Map<String, dynamic>>> fetchMoods() => _fetchRaw(
      'moods', buildUserScopedQueries(userId, orderBy: Query.orderAsc('date_key')));

  @override
  Future<void> upsertMood(String dateKey, String data) async {
    await _upsertRow(
      tableId: 'moods',
      rowId: _compositeId(dateKey),
      data: {
        'user_id': userId,
        'date_key': dateKey,
        'data': data,
      },
    );
  }

  @override
  Future<void> deleteMood(String dateKey) async {
    await _tablesDB.deleteRow(
      databaseId: databaseId,
      tableId: 'moods',
      rowId: _compositeId(dateKey),
    );
  }

  // ─── Journal Entries (C.5) — hard delete ────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchJournalEntries() =>
      _fetchAllRows(
          'journal_entries',
          buildUserScopedQueries(userId, orderBy: Query.orderDesc(r'$createdAt')));

  @override
  Future<void> upsertJournalEntry(
      String dateKey, Map<String, dynamic> entry) async {
    await _upsertRow(
      tableId: 'journal_entries',
      rowId: entry['id'] as String,
      data: {
        'user_id': userId,
        'date_key': dateKey,
        'content': entry['content'],
      },
    );
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    await _tablesDB.deleteRow(
      databaseId: databaseId,
      tableId: 'journal_entries',
      rowId: entryId,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  /// Project an Appwrite `Row` back to the row shape downstream
  /// repositories expect: snake_case fields, `id` set, `created_at` /
  /// `updated_at` populated from the auto-managed `$createdAt` /
  /// `$updatedAt` (which are already ISO 8601 strings in SDK 21.4.0).
  Map<String, dynamic> _rowToMap(Row row) {
    final data = Map<String, dynamic>.from(row.data);
    data['id'] = row.$id;
    data['created_at'] = row.$createdAt;
    data['updated_at'] = row.$updatedAt;
    return data;
  }

  /// Composite row id for special_days and moods (one row per
  /// user × date). Matches the Supabase convention.
  String _compositeId(String dateKey) => '${userId}_$dateKey';
}
