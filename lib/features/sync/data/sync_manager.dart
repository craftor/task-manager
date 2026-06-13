import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show immutable;
import '../../../core/utils/logger.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/datasources/local/app_database.dart';
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
    _connectivitySubscription?.cancel();
    _periodicSync?.cancel();
    _syncStateController.close();
  }
}
