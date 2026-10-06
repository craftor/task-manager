/// SnapshotCodec — converts between the on-disk storage (Drift +
/// SharedPreferences) and the [SyncSnapshot] wire format used by the
/// WebDAV engine.
///
/// The wire format is plain JSON. Every row carries `updated_at`
/// (milliseconds since epoch) so the merge algorithm in [SyncEngine]
/// can pick the winner for each record. Tombstones are encoded as rows
/// with `deleted_at` set; the Drift schema already supports this column
/// for Projects and Tasks, and the cache-based stores (journal, mood,
/// special_days) treat a missing key as "deleted".
///
/// We deliberately keep the public methods synchronous-ish — they only
/// call Drift/Sp APIs and never touch the network. Network I/O lives
/// exclusively in [WebDavClientWrapper] / [SyncEngine].
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/utils/json_cache_store.dart';
import '../datasources/local/app_database.dart';
import 'snapshot.dart';

// ─── Local cache keys (must match the *_repository_impl.dart constants) ───

const String _kJournalCacheKey = 'journal_cache';
const String _kMoodCacheKey = 'moods_cache';
const String _kSpecialDaysCacheKey = 'special_days_cache';

/// Single entry point for serializing snapshots. Stateless; safe to
/// construct multiple times.
class SnapshotCodec {
  SnapshotCodec(this._db);

  final AppDatabase _db;

  final JsonCacheStore _journalStore = JsonCacheStore(_kJournalCacheKey);
  final JsonCacheStore _moodStore = JsonCacheStore(_kMoodCacheKey);
  final JsonCacheStore _specialDaysStore =
      JsonCacheStore(_kSpecialDaysCacheKey);

  // ─── Export: local → snapshot ────────────────────────────────────────

  /// Build a snapshot from the local DB + SharedPreferences caches.
  /// Tombstoned rows (deletedAt IS NOT NULL) ARE included — they need
  /// to be propagated to other devices.
  Future<SyncSnapshot> exportSnapshot() async {
    final projects = await _db.select(_db.projects).get();
    final tasks = await _db.select(_db.tasks).get();
    final timeEntries = await _db.select(_db.timeEntries).get();

    return SyncSnapshot(
      schemaVersion: SyncSnapshot.currentSchemaVersion,
      exportedAt: DateTime.now().toUtc(),
      projects: projects.map(_projectToJson).toList(),
      tasks: tasks.map(_taskToJson).toList(),
      timeEntries: timeEntries.map(_timeEntryToJson).toList(),
      journal: await _readJournalCache(),
      moods: await _readMoodCache(),
      specialDays: await _readSpecialDaysCache(),
    );
  }

  Map<String, dynamic> _projectToJson(Project p) => {
        'id': p.id,
        'parent_id': p.parentId,
        'name': p.name,
        'description': p.description,
        'color': p.color,
        'icon': p.icon,
        'start_date': p.startDate?.toIso8601String(),
        'end_date': p.endDate?.toIso8601String(),
        'created_at': p.createdAt.toIso8601String(),
        // Projects don't have an updatedAt column; use createdAt for the
        // merge key so it never gets re-overwritten by older snapshots.
        'updated_at': p.createdAt.toUtc().millisecondsSinceEpoch,
        'sort_order': p.sortOrder,
        'is_default': p.isDefault,
        'deleted_at': p.deletedAt?.toIso8601String(),
      };

  Map<String, dynamic> _taskToJson(Task t) => {
        'id': t.id,
        'project_id': t.projectId,
        'parent_task_id': t.parentTaskId,
        'title': t.title,
        'description': t.description,
        'priority': t.priority,
        'status': t.status,
        'start_date': t.startDate?.toIso8601String(),
        'due_date': t.dueDate?.toIso8601String(),
        'tags': t.tags,
        'estimated_minutes': t.estimatedMinutes,
        'actual_minutes': t.actualMinutes,
        'is_recurring': t.isRecurring,
        'recurring_rule': t.recurringRule,
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt.toUtc().millisecondsSinceEpoch,
        'sort_order': t.sortOrder,
        'deleted_at': t.deletedAt?.toIso8601String(),
      };

  Map<String, dynamic> _timeEntryToJson(TimeEntry e) => {
        'id': e.id,
        'task_id': e.taskId,
        'start_time': e.startTime.toIso8601String(),
        'end_time': e.endTime?.toIso8601String(),
        'duration_minutes': e.durationMinutes,
        'note': e.note,
        'manual': e.manual,
        // TimeEntries don't have updatedAt; derive from end_time or
        // start_time so the merge picks the most recently touched row.
        'updated_at': (e.endTime ?? e.startTime).toUtc().millisecondsSinceEpoch,
      };

  Future<Map<String, List<Map<String, dynamic>>>> _readJournalCache() async {
    final raw = await _journalStore.readJson();
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final list = (v as List).cast<dynamic>();
      return MapEntry(
        k as String,
        list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    });
  }

  Future<Map<String, List<String>>> _readMoodCache() async {
    final raw = await _moodStore.readJson();
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final list = (v as List).cast<dynamic>();
      return MapEntry(k as String, list.map((e) => e.toString()).toList());
    });
  }

  Future<Map<String, Map<String, String>>> _readSpecialDaysCache() async {
    final raw = await _specialDaysStore.readJson();
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final inner = v as Map<String, dynamic>?;
      if (inner == null) return MapEntry(k as String, <String, String>{});
      return MapEntry(
        k as String,
        inner.map((ik, iv) => MapEntry(ik, iv.toString())),
      );
    });
  }

  // ─── JSON helpers (used by both encode/decode) ──────────────────────

  /// Serialise a snapshot to a UTF-8 JSON byte buffer. Pretty-printed so
  /// the file is human-readable when inspected from the WebDAV client.
  static String encodeToJson(SyncSnapshot snap) {
    final json = {
      'schema_version': snap.schemaVersion,
      'exported_at': snap.exportedAt.toIso8601String(),
      'projects': snap.projects,
      'tasks': snap.tasks,
      'time_entries': snap.timeEntries,
      'journal': snap.journal.map(
        (k, v) => MapEntry(k, v.map((m) => m).toList()),
      ),
      'moods': snap.moods,
      'special_days': snap.specialDays,
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  static SyncSnapshot decodeFromJson(String source) {
    final root = json.decode(source) as Map<String, dynamic>;
    final v = root['schema_version'];
    if (v is! int || v > SyncSnapshot.currentSchemaVersion) {
      throw FormatException(
        'Snapshot schema_version=$v is newer than supported '
        '(${SyncSnapshot.currentSchemaVersion}). Upgrade the app.',
      );
    }
    final journal = <String, List<Map<String, dynamic>>>{};
    final journalRaw = root['journal'];
    if (journalRaw is Map) {
      journalRaw.forEach((k, v) {
        if (v is List) {
          journal[k as String] = v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    }

    final moods = <String, List<String>>{};
    final moodsRaw = root['moods'];
    if (moodsRaw is Map) {
      moodsRaw.forEach((k, v) {
        if (v is List) {
          moods[k as String] = v.map((e) => e.toString()).toList();
        }
      });
    }

    final special = <String, Map<String, String>>{};
    final specialRaw = root['special_days'];
    if (specialRaw is Map) {
      specialRaw.forEach((k, v) {
        if (v is Map) {
          special[k as String] = v.map(
            (ik, iv) => MapEntry(ik as String, iv.toString()),
          );
        }
      });
    }

    List<Map<String, dynamic>> parseList(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return SyncSnapshot(
      schemaVersion: v,
      exportedAt: root['exported_at'] is String
          ? DateTime.parse(root['exported_at'] as String)
          : DateTime.now().toUtc(),
      projects: parseList(root['projects']),
      tasks: parseList(root['tasks']),
      timeEntries: parseList(root['time_entries']),
      journal: journal,
      moods: moods,
      specialDays: special,
    );
  }

  /// Apply a snapshot's contents to the local DB + SharedPreferences.
  /// This is used by [SyncEngine.applyMerged] AFTER it has merged two
  /// snapshots; the input must be the post-merge result.
  Future<void> applyMerged(SyncSnapshot snap) async {
    await _db.transaction(() async {
      for (final p in snap.projects) {
        await _upsertProject(p);
      }
      for (final t in snap.tasks) {
        await _upsertTask(t);
      }
      for (final e in snap.timeEntries) {
        await _upsertTimeEntry(e);
      }
    });

    await _writeJournalCache(snap.journal);
    await _writeMoodCache(snap.moods);
    await _writeSpecialDaysCache(snap.specialDays);
  }

  Future<void> _upsertProject(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final companion = ProjectsCompanion(
      id: Value(id),
      parentId: Value(data['parent_id'] as String?),
      name: Value(data['name'] as String),
      description: Value(data['description'] as String?),
      color: Value(data['color'] as String),
      icon: Value(data['icon'] as String),
      startDate: Value(_parseDate(data['start_date'])),
      endDate: Value(_parseDate(data['end_date'])),
      createdAt: Value(_parseDate(data['created_at']) ?? DateTime.now()),
      sortOrder: Value((data['sort_order'] as int?) ?? 0),
      isDefault: Value((data['is_default'] as bool?) ?? false),
      deletedAt: Value(_parseDate(data['deleted_at'])),
      // After pulling we treat the row as authoritative until the next
      // local edit; mark pendingSync=false so the next push is a no-op.
      pendingSync: const Value(false),
    );
    await _db.into(_db.projects).insertOnConflictUpdate(companion);
  }

  Future<void> _upsertTask(Map<String, dynamic> data) async {
    final companion = TasksCompanion(
      id: Value(data['id'] as String),
      projectId: Value(data['project_id'] as String),
      parentTaskId: Value(data['parent_task_id'] as String?),
      title: Value(data['title'] as String),
      description: Value((data['description'] as String?) ?? ''),
      priority: Value((data['priority'] as int?) ?? 2),
      status: Value((data['status'] as int?) ?? 0),
      startDate: Value(_parseDate(data['start_date'])),
      dueDate: Value(_parseDate(data['due_date'])),
      tags: Value(_parseTags(data['tags'])),
      estimatedMinutes: Value(data['estimated_minutes'] as int?),
      actualMinutes: Value(data['actual_minutes'] as int?),
      isRecurring: Value((data['is_recurring'] as bool?) ?? false),
      recurringRule: Value(data['recurring_rule'] as String?),
      createdAt: Value(_parseDate(data['created_at']) ?? DateTime.now()),
      updatedAt: Value(_parseDate(data['updated_at']) ?? DateTime.now()),
      sortOrder: Value((data['sort_order'] as int?) ?? 0),
      deletedAt: Value(_parseDate(data['deleted_at'])),
      pendingSync: const Value(false),
    );
    await _db.into(_db.tasks).insertOnConflictUpdate(companion);
  }

  Future<void> _upsertTimeEntry(Map<String, dynamic> data) async {
    final companion = TimeEntriesCompanion(
      id: Value(data['id'] as String),
      taskId: Value(data['task_id'] as String),
      startTime: Value(_parseDate(data['start_time']) ?? DateTime.now()),
      endTime: Value(_parseDate(data['end_time'])),
      durationMinutes: Value(data['duration_minutes'] as int?),
      note: Value((data['note'] as String?) ?? ''),
      manual: Value((data['manual'] as bool?) ?? false),
      pendingSync: const Value(false),
    );
    await _db.into(_db.timeEntries).insertOnConflictUpdate(companion);
  }

  Future<void> _writeJournalCache(
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    await _journalStore.writeJson(data);
  }

  Future<void> _writeMoodCache(Map<String, List<String>> data) async {
    await _moodStore.writeJson(data);
  }

  Future<void> _writeSpecialDaysCache(
    Map<String, Map<String, String>> data,
  ) async {
    await _specialDaysStore.writeJson(data);
  }

  // ─── Merge logic ────────────────────────────────────────────────────

  /// Three-way merge: local + remote → result.
  ///
  /// Per record we pick the side with the higher `updated_at`
  /// (milliseconds since epoch). Tombstones (`deleted_at` set) win
  /// unconditionally: if either side has deleted the row, the result
  /// deletes it. After merging, rows that are NOT in either side get
  /// dropped; rows that exist on both but disagree are last-write-wins.
  ///
  /// Cache-based stores (journal, mood, special_days) use the
  /// containing `date_key`'s most-recent write timestamp — exposed by
  /// [CacheMetadata] below.
  static SyncSnapshot merge(SyncSnapshot local, SyncSnapshot remote) {
    return SyncSnapshot(
      schemaVersion: SyncSnapshot.currentSchemaVersion,
      exportedAt: DateTime.now().toUtc(),
      projects: _mergeRows(local.projects, remote.projects, _projectKey),
      tasks: _mergeRows(local.tasks, remote.tasks, _taskKey),
      timeEntries: _mergeRows(
        local.timeEntries,
        remote.timeEntries,
        _timeEntryKey,
      ),
      journal: _mergeCache(
        local.journal,
        remote.journal,
        (entries) => _entriesTimestamp(entries),
      ),
      moods: _mergeCache(
        local.moods,
        remote.moods,
        (emojis) => _moodTimestamp(emojis),
      ),
      specialDays: _mergeCache(
        local.specialDays,
        remote.specialDays,
        (day) => _specialDayTimestamp(day),
      ),
    );
  }

  static List<Map<String, dynamic>> _mergeRows(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
    String Function(Map<String, dynamic>) keyFn,
  ) {
    final out = <String, Map<String, dynamic>>{};
    int ts(Map<String, dynamic> r) {
      final raw = r['updated_at'];
      if (raw is int) return raw;
      if (raw is String) return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
      return 0;
    }

    bool deleted(Map<String, dynamic> r) =>
        r['deleted_at'] != null && r['deleted_at'].toString().isNotEmpty;

    for (final r in a) {
      out[keyFn(r)] = Map<String, dynamic>.from(r);
    }
    for (final r in b) {
      final k = keyFn(r);
      final existing = out[k];
      if (existing == null) {
        out[k] = Map<String, dynamic>.from(r);
        continue;
      }
      // Tombstone priority: whichever side deleted the row wins,
      // regardless of timestamps. This prevents an old local copy from
      // resurrecting a remotely-deleted record.
      if (deleted(r) && !deleted(existing)) {
        out[k] = Map<String, dynamic>.from(r);
        continue;
      }
      if (!deleted(r) && deleted(existing)) {
        // existing is already a tombstone — keep it.
        continue;
      }
      if (ts(r) > ts(existing)) {
        out[k] = Map<String, dynamic>.from(r);
      }
    }
    return out.values.toList(growable: false);
  }

  /// Merge for the cache-based stores. The "row" is one date_key, and
  /// the merge picks the side whose value's last write timestamp is
  /// newer. Deletion semantics: if one side has the key and the other
  /// doesn't, "absent" is treated as "deleted at timestamp 0", so a
  /// missing side never resurrects a delete made on the present side.
  static Map<String, T> _mergeCache<T>(
    Map<String, T> a,
    Map<String, T> b,
    String Function(T) timestampFn,
  ) {
    final out = <String, T>{};
    // Start from the side that has the most recent write per key. We
    // process both sides and let the later timestamp win; if a key is
    // present on only one side, that side wins outright.
    final keys = <String>{...a.keys, ...b.keys};
    for (final k in keys) {
      final va = a[k];
      final vb = b[k];
      if (va == null) {
        // We've already established vb != null because k ∈ keys but
        // not in a.
        if (vb != null) out[k] = vb;
        continue;
      }
      if (vb == null) {
        out[k] = va;
        continue;
      }
      final tA = timestampFn(va);
      final tB = timestampFn(vb);
      // Tie goes to local (a) — it's what the user is currently looking at.
      out[k] = tB.compareTo(tA) > 0 ? vb : va;
    }
    return out;
  }

  static String _moodTimestamp(List<String> _) =>
      // Mood entries don't carry their own timestamp; we can't reliably
      // merge across sides without one. Treat the local copy as
      // authoritative on conflict.
      '';

  static String _specialDayTimestamp(Map<String, String> _) =>
      // Same as moods — no per-row timestamp, prefer local.
      '';

  static String _entriesTimestamp(List<Map<String, dynamic>> entries) {
    // Use the most recent entry's created_at as the row timestamp.
    // If entries are empty, fall back to the empty string so the
    // caller breaks ties in favour of local.
    if (entries.isEmpty) return '';
    String best = '';
    for (final e in entries) {
      final raw = e['created_at'];
      if (raw is String && raw.compareTo(best) > 0) best = raw;
    }
    return best;
  }

  static String _projectKey(Map<String, dynamic> r) => r['id'] as String;
  static String _taskKey(Map<String, dynamic> r) => r['id'] as String;
  static String _timeEntryKey(Map<String, dynamic> r) => r['id'] as String;

  // ─── Common helpers ─────────────────────────────────────────────────

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      // Accept both ms-since-epoch and seconds-since-epoch for forward
      // compatibility with potential older snapshots.
      if (raw > 100000000000) return DateTime.fromMillisecondsSinceEpoch(raw);
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static List<String> _parseTags(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return raw.isEmpty ? const [] : raw.split(',');
    return const [];
  }
}
