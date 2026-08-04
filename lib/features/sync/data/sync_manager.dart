import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show immutable;
import '../../../core/utils/logger.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/datasources/remote/appwrite_datasource.dart';
import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../../../domain/entities/project.dart' as entity;
import '../../../../domain/entities/task.dart' as task_entity;
import '../../../../domain/entities/time_entry.dart' as time_entity;
import '../../journal/domain/journal_repository.dart';
import '../../mood/domain/mood_repository.dart';
import '../../special_days/domain/special_days_repository.dart';

enum SyncStatus { idle, syncing, success, error }

@immutable
class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.lastSyncTime,
  });
}

class SyncManager {
  final AppDatabase _localDb;
  final RemoteDatasource _remoteDs;
  final JournalRepository _journalRepo;
  final MoodRepository _moodRepo;
  final SpecialDaysRepository _specialDaysRepo;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSync;
  RealtimeSubscription? _realtimeSub;

  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  SyncManager(
    this._localDb,
    this._remoteDs, {
    required JournalRepository journalRepository,
    required MoodRepository moodRepository,
    required SpecialDaysRepository specialDaysRepository,
  })  : _journalRepo = journalRepository,
        _moodRepo = moodRepository,
        _specialDaysRepo = specialDaysRepository {
    Logger.d('SyncManager: created, initializing listeners');
    _initConnectivityListener();
    _initPeriodicSync();
    _initRealtime();
    // Trigger initial sync after a short delay to let auth settle
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        syncAll();
      } catch (e, st) {
        Logger.e('SyncManager: initial sync setup failed', error: e, stackTrace: st);
      }
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) async {
        if (result != ConnectivityResult.none) {
          await syncAll();
        }
      },
    );
  }

  void _initPeriodicSync() {
    _periodicSync = Timer.periodic(
      AppConstants.syncInterval,
      (_) => syncAll(),
    );
  }

  /// Appwrite Realtime subscription — complements the 5-min poll with
  /// instant change notifications. Pending policy: local rows with
  /// `pendingSync=true` are authoritative; [upsert*FromRemote] skips
  /// them, so we never clobber unsynced local edits.
  ///
  /// Only attaches to [AppwriteDatasource] (the only backend in use).
  /// Other datasource implementations get the poll-only behavior.
  void _initRealtime() {
    if (_remoteDs is! AppwriteDatasource) return;
    final appwrite = _remoteDs as AppwriteDatasource;
    final channels = AppConstants.realtimeChannels
        .map((c) => 'databases.${appwrite.databaseId}.collections.$c.documents')
        .toList();
    try {
      _realtimeSub = appwrite.realtime.subscribe(channels);
      _realtimeSub!.stream.listen(_onRealtimeEvent,
          onError: (Object e, StackTrace st) {
        Logger.e('SyncManager: realtime stream error', error: e, stackTrace: st);
      });
      Logger.d('SyncManager: realtime subscribed to ${channels.length} channels');
    } catch (e, st) {
      Logger.e('SyncManager: realtime subscribe failed', error: e, stackTrace: st);
    }
  }

  /// Route a Realtime event to the matching local write. Filters out
  /// events for other users (`payload['user_id']`) before doing any
  /// work — the Appwrite server doesn't filter by user on its own
  /// when the client subscribes with the wildcard channel.
  void _onRealtimeEvent(RealtimeMessage msg) {
    if (msg.payload.isEmpty) return;
    final payloadUserId = msg.payload['user_id'];
    if (payloadUserId != null && payloadUserId != _userIdOf(_remoteDs)) return;

    final collection = _collectionFromChannel(msg.channels);
    if (collection == null) return;

    final event = msg.events.isNotEmpty ? msg.events.first : '';
    final isDelete = event.endsWith('.delete');

    // Build a row map mirroring what the REST listDocuments path
    // produces (snake_case fields, `id` set, `created_at`/`updated_at`).
    final row = _payloadToRow(msg.payload, isDelete: isDelete);
    if (row == null) return;

    switch (collection) {
      case 'projects':
        if (isDelete) {
          // Soft-delete is propagated as a row with `deleted_at`. The
          // delete-only branch here is a safety net for an actual
          // server-side hard delete (shouldn't happen for projects).
          _localDb.upsertProjectFromRemote(row);
        } else {
          _localDb.upsertProjectFromRemote(row);
        }
        break;
      case 'tasks':
        if (isDelete) {
          _localDb.upsertTaskFromRemote(row);
        } else {
          _localDb.upsertTaskFromRemote(row);
        }
        break;
      case 'time_entries':
        if (isDelete) {
          // Time entries are hard-deleted server-side; replicate that
          // locally so the local cache doesn't keep a tombstone.
          _localDb.deleteTimeEntry(row['id'] as String);
        } else {
          _localDb.upsertTimeEntryFromRemote(row);
        }
        break;
      case 'journal_entries':
        final dateKey = row['date_key'] as String?;
        final id = row['id'] as String;
        if (dateKey == null) return;
        if (isDelete) {
          _journalRepo.applyRemoteDeleteEntry(dateKey, id);
        } else {
          _journalRepo.applyRemoteUpsertEntry(
            dateKey,
            {
              'id': id,
              'created_at': row['created_at'],
              'content': row['content'],
            },
          );
        }
        break;
      case 'moods':
        final dateKey = row['date_key'] as String?;
        if (dateKey == null) return;
        if (isDelete) {
          _moodRepo.applyRemoteDeleteMood(dateKey);
        } else {
          _moodRepo.applyRemoteMood(dateKey, row['data'] as String? ?? '[]');
        }
        break;
      case 'special_days':
        final dateKey = row['date_key'] as String?;
        if (dateKey == null) return;
        if (isDelete) {
          _specialDaysRepo.applyRemoteDeleteDay(dateKey);
        } else {
          _specialDaysRepo.applyRemoteDay(dateKey, row['data'] as String? ?? '{}');
        }
        break;
    }
  }

  String? _collectionFromChannel(List<String> channels) {
    for (final c in channels) {
      for (final id in AppConstants.realtimeChannels) {
        if (c.contains('.collections.$id.')) return id;
      }
    }
    return null;
  }

  String? _userIdOf(RemoteDatasource ds) {
    if (ds is AppwriteDatasource) return ds.userId;
    return null;
  }

  Map<String, dynamic>? _payloadToRow(Map<String, dynamic> payload,
      {required bool isDelete}) {
    final id = payload[r'$id'] as String?;
    if (id == null) return null;
    final row = Map<String, dynamic>.from(payload);
    row['id'] = id;
    row['created_at'] = payload[r'$createdAt'] ?? row['created_at'];
    row['updated_at'] = payload[r'$updatedAt'] ?? row['updated_at'];
    return row;
  }

  Future<void> syncAll() async {
    Logger.d('SyncManager.syncAll: starting');
    _syncStateController.add(const SyncState(status: SyncStatus.syncing));
    try {
      await _syncPendingChanges();
      await _pullRemoteChanges();
      Logger.d('SyncManager.syncAll: completed successfully');
      _syncStateController.add(SyncState(
        status: SyncStatus.success,
        lastSyncTime: DateTime.now(),
      ));
    } catch (e, st) {
      Logger.e('SyncManager.syncAll error', error: e, stackTrace: st);
      _syncStateController.add(SyncState(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _syncPendingChanges() async {
    // Sync pending projects (skip the non-UUID default project from old installs)
    final pendingProjects = await _localDb.getPendingProjects();
    Logger.d('SyncManager._syncPendingChanges: ${pendingProjects.length} pending projects');
    for (final driftProject in pendingProjects) {
      final isTombstone = driftProject.deletedAt != null;
      if (isTombstone) {
        // Soft-delete in flight: push the tombstone, then on success
        // physical-delete locally so we never resurrect it from a future
        // pull. If the push fails, leave the row — `_pendingProjects` will
        // return it on the next tick.
        await _remoteDs.upsertProject(
          entity.Project(
            id: driftProject.id,
            parentId: driftProject.parentId,
            name: driftProject.name,
            description: driftProject.description,
            color: driftProject.color,
            icon: driftProject.icon,
            startDate: driftProject.startDate,
            endDate: driftProject.endDate,
            createdAt: driftProject.createdAt,
            isDefault: driftProject.isDefault,
            sortOrder: driftProject.sortOrder,
          ),
          deletedAt: driftProject.deletedAt,
        );
        await _localDb.deleteProject(driftProject.id);
      } else {
        final domainProject = entity.Project(
          id: driftProject.id,
          parentId: driftProject.parentId,
          name: driftProject.name,
          description: driftProject.description,
          color: driftProject.color,
          icon: driftProject.icon,
          startDate: driftProject.startDate,
          endDate: driftProject.endDate,
          createdAt: driftProject.createdAt,
          isDefault: driftProject.isDefault,
          sortOrder: driftProject.sortOrder,
        );
        await _remoteDs.upsertProject(domainProject);
        await _localDb.markProjectSynced(driftProject.id);
      }
    }

    // Sync pending tasks
    final pendingTasks = await _localDb.getPendingTasks();
    Logger.d('SyncManager._syncPendingChanges: ${pendingTasks.length} pending tasks');
    for (final driftTask in pendingTasks) {
      final isTombstone = driftTask.deletedAt != null;
      if (isTombstone) {
        await _remoteDs.upsertTask(
          task_entity.Task(
            id: driftTask.id,
            projectId: driftTask.projectId,
            parentTaskId: driftTask.parentTaskId,
            title: driftTask.title,
            description: driftTask.description,
            priority: task_entity.Priority.values[driftTask.priority],
            status: task_entity.TaskStatus.values[driftTask.status],
            startDate: driftTask.startDate,
            dueDate: driftTask.dueDate,
            tags: driftTask.tags,
            estimatedMinutes: driftTask.estimatedMinutes,
            actualMinutes: driftTask.actualMinutes,
            isRecurring: driftTask.isRecurring,
            recurringRule: driftTask.recurringRule,
            createdAt: driftTask.createdAt,
            updatedAt: driftTask.updatedAt,
            sortOrder: driftTask.sortOrder,
          ),
          deletedAt: driftTask.deletedAt,
        );
        await _localDb.deleteTask(driftTask.id);
      } else {
        final domainTask = task_entity.Task(
          id: driftTask.id,
          projectId: driftTask.projectId,
          parentTaskId: driftTask.parentTaskId,
          title: driftTask.title,
          description: driftTask.description,
          priority: task_entity.Priority.values[driftTask.priority],
          status: task_entity.TaskStatus.values[driftTask.status],
          startDate: driftTask.startDate,
          dueDate: driftTask.dueDate,
          tags: driftTask.tags,
          estimatedMinutes: driftTask.estimatedMinutes,
          actualMinutes: driftTask.actualMinutes,
          isRecurring: driftTask.isRecurring,
          recurringRule: driftTask.recurringRule,
          createdAt: driftTask.createdAt,
          updatedAt: driftTask.updatedAt,
          sortOrder: driftTask.sortOrder,
        );
        await _remoteDs.upsertTask(domainTask);
        await _localDb.markTaskSynced(driftTask.id);
      }
    }

    // Sync pending time entries
    final pendingTimeEntries = await _localDb.getPendingTimeEntries();
    Logger.d('SyncManager._syncPendingChanges: ${pendingTimeEntries.length} pending time entries');
    for (final driftEntry in pendingTimeEntries) {
      final domainEntry = time_entity.TimeEntry(
        id: driftEntry.id,
        taskId: driftEntry.taskId,
        startTime: driftEntry.startTime,
        endTime: driftEntry.endTime,
        durationMinutes: driftEntry.durationMinutes,
        note: driftEntry.note,
        manual: driftEntry.manual,
      );
      await _remoteDs.upsertTimeEntry(domainEntry);
      await _localDb.markTimeEntrySynced(driftEntry.id);
    }
  }

  Future<void> _pullRemoteChanges() async {
    final remoteProjects = await _remoteDs.fetchProjects();
    Logger.d('SyncManager._pullRemoteChanges: ${remoteProjects.length} remote projects');
    // Only keep one default project (prefer the fixed UUID)
    final List<Map<String, dynamic>> filtered = [];
    final remoteProjectIds = <String>{};
    bool hasFixedDefault = false;
    for (final p in remoteProjects) {
      final isDefault = (p['name'] as String?)?.toLowerCase() == 'default' || (p['is_default'] as bool?) == true;
      if (isDefault) {
        if (p['id'] == AppConstants.defaultProjectId) {
          hasFixedDefault = true;
          filtered.add(p);
          remoteProjectIds.add(p['id'] as String);
        } else if (!hasFixedDefault) {
          filtered.add(p);
          remoteProjectIds.add(p['id'] as String);
          hasFixedDefault = true;
        }
      } else {
        filtered.add(p);
        remoteProjectIds.add(p['id'] as String);
      }
    }
    for (final p in filtered) {
      await _localDb.upsertProjectFromRemote(p);
    }
    // Purge synced local projects not on remote. Skip tombstones (deletedAt
    // != null) so an offline-delete doesn't get clobbered by a pull that
    // happens before the tombstone push completes.
    final localSyncedProjects = await _localDb.getAllProjectsIncludingDeleted();
    for (final local in localSyncedProjects) {
      if (local.pendingSync) continue;
      if (local.deletedAt != null) continue;
      if (!remoteProjectIds.contains(local.id)) {
        Logger.d('SyncManager: pruning locally deleted project ${local.id}');
        await _localDb.deleteProject(local.id);
      }
    }

    final remoteTasks = await _remoteDs.fetchTasks();
    Logger.d('SyncManager._pullRemoteChanges: ${remoteTasks.length} remote tasks');
    final remoteTaskIds = remoteTasks.map((t) => t['id'] as String).toSet();
    for (final t in remoteTasks) {
      await _localDb.upsertTaskFromRemote(t);
    }
    // Purge synced local tasks that are no longer on remote (were deleted
    // remotely). Skip tombstones for the same reason as projects above.
    final localSyncedTasks = await _localDb.getAllTasksIncludingDeleted();
    for (final local in localSyncedTasks) {
      if (local.pendingSync) continue;
      if (local.deletedAt != null) continue;
      if (!remoteTaskIds.contains(local.id)) {
        Logger.d('SyncManager: pruning locally deleted task ${local.id}');
        await _localDb.deleteTask(local.id);
      }
    }

    final remoteTimeEntries = await _remoteDs.fetchTimeEntries();
    Logger.d('SyncManager._pullRemoteChanges: ${remoteTimeEntries.length} remote time entries');
    for (final e in remoteTimeEntries) {
      await _localDb.upsertTimeEntryFromRemote(e);
    }

    // Special Days (Appwrite → Repository → SharedPreferences cache)
    try {
      await _specialDaysRepo.pullFromRemote(_remoteDs);
      Logger.d('SyncManager._pullRemoteChanges: special days refreshed');
    } catch (e, st) {
      Logger.e('SyncManager._pullRemoteChanges: special days sync failed',
          error: e, stackTrace: st);
    }

    // Journal Entries (Appwrite → Repository → SharedPreferences cache)
    try {
      await _journalRepo.pullFromRemote(_remoteDs);
      Logger.d('SyncManager._pullRemoteChanges: journal refreshed');
    } catch (e, st) {
      Logger.e('SyncManager._pullRemoteChanges: journal sync failed',
          error: e, stackTrace: st);
    }

    // Moods (Appwrite → Repository → SharedPreferences cache)
    try {
      await _moodRepo.pullFromRemote(_remoteDs);
      Logger.d('SyncManager._pullRemoteChanges: moods refreshed');
    } catch (e, st) {
      Logger.e('SyncManager._pullRemoteChanges: moods sync failed',
          error: e, stackTrace: st);
    }
  }

  void dispose() {
    _realtimeSub?.close();
    _connectivitySubscription?.cancel();
    _periodicSync?.cancel();
    _syncStateController.close();
  }
}
