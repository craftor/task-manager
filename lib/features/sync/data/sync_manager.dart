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
import '../../special_days/special_days_cache_helper.dart';
import '../../journal/journal_cache_helper.dart';
import '../../mood/mood_service.dart';

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
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSync;

  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  SyncManager(this._localDb, this._remoteDs) {
    Logger.d('SyncManager: created, initializing listeners');
    _initConnectivityListener();
    _initPeriodicSync();
    // Trigger initial sync after a short delay to let auth settle
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        // Fix legacy tasks: re-map projectId and re-mark for sync
        final tasks = await _localDb.getAllTasks();
        for (final t in tasks) {
          if (t.projectId == AppConstants.legacyDefaultProjectId) {
            await _localDb.fixLegacyTaskProject(t.id);
          }
        }
        // Clean up duplicate default projects in local DB
        await _localDb.cleanupDuplicateDefaultProjects();
        Logger.d('SyncManager: triggering initial sync');
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
    } catch (e) {
      Logger.d('SyncManager.syncAll: error - $e');
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
      // Skip legacy default project with non-UUID id
      if (driftProject.id == AppConstants.legacyDefaultProjectId) {
        Logger.d('SyncManager: skipping legacy default project');
        await _localDb.markProjectSynced(driftProject.id);
        continue;
      }
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

    // Sync pending tasks
    final pendingTasks = await _localDb.getPendingTasks();
    Logger.d('SyncManager._syncPendingChanges: ${pendingTasks.length} pending tasks');
    for (final driftTask in pendingTasks) {
      // Remap legacy default-project to fixed UUID
      final fixedProjectId = driftTask.projectId == AppConstants.legacyDefaultProjectId
          ? AppConstants.defaultProjectId
          : driftTask.projectId;
      final domainTask = task_entity.Task(
        id: driftTask.id,
        projectId: fixedProjectId,
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
    // Purge synced local projects not on remote
    final localSyncedProjects = await _localDb.getAllProjects();
    for (final local in localSyncedProjects) {
      if (local.pendingSync) continue;
      if (!remoteProjectIds.contains(local.id)) {
        Logger.d('SyncManager: pruning locally deleted project ${local.id}');
        await _localDb.deleteProjectById(local.id);
      }
    }

    final remoteTasks = await _remoteDs.fetchTasks();
    Logger.d('SyncManager._pullRemoteChanges: ${remoteTasks.length} remote tasks');
    final remoteTaskIds = remoteTasks.map((t) => t['id'] as String).toSet();
    for (final t in remoteTasks) {
      await _localDb.upsertTaskFromRemote(t);
    }
    // Purge synced local tasks that are no longer on remote (were deleted remotely)
    final localSyncedTasks = await _localDb.getAllTasks();
    for (final local in localSyncedTasks) {
      if (local.pendingSync) continue; // skip unsynced local creates
      if (!remoteTaskIds.contains(local.id)) {
        Logger.d('SyncManager: pruning locally deleted task ${local.id}');
        await _localDb.deleteTaskById(local.id);
      }
    }

    final remoteTimeEntries = await _remoteDs.fetchTimeEntries();
    Logger.d('SyncManager._pullRemoteChanges: ${remoteTimeEntries.length} remote time entries');
    for (final e in remoteTimeEntries) {
      await _localDb.upsertTimeEntryFromRemote(e);
    }

    // Special Days (stored in Supabase, cached in SharedPreferences)
    try {
      final specialDaysRaw = await _remoteDs.fetchSpecialDays();
      Logger.d('SyncManager._pullRemoteChanges: ${specialDaysRaw.length} special days from remote');
      // Always merge to ensure deletions on other devices are reflected
      SpecialDaysCacheHelper.mergeRemoteData(specialDaysRaw);
    } catch (e) {
      Logger.d('SyncManager._pullRemoteChanges: special days sync failed — $e');
    }

    // Journal Entries (stored in Supabase, cached in SharedPreferences)
    try {
      final journalRaw = await _remoteDs.fetchJournalEntries();
      Logger.d('SyncManager._pullRemoteChanges: ${journalRaw.length} journal entries from remote');
      // Always merge to ensure deletions on other devices are reflected
      JournalCacheHelper.mergeRemoteData(journalRaw);
    } catch (e) {
      Logger.d('SyncManager._pullRemoteChanges: journal sync failed — $e');
    }

    // Moods (stored in Supabase, cached in SharedPreferences)
    try {
      final moodsRaw = await _remoteDs.fetchMoods();
      Logger.d('SyncManager._pullRemoteChanges: ${moodsRaw.length} moods from remote');
      // Always merge to ensure deletions on other devices are reflected
      MoodService.mergeRemoteData(moodsRaw);
    } catch (e) {
      Logger.d('SyncManager._pullRemoteChanges: moods sync failed — $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSync?.cancel();
    _syncStateController.close();
  }
}
