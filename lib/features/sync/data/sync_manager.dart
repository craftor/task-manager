import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/datasources/remote/supabase_datasource.dart';
import '../../../../domain/entities/project.dart' as entity;
import '../../../../domain/entities/task.dart' as task_entity;
import '../../../../domain/entities/time_entry.dart' as time_entity;
import '../../special_days/special_days_cache_helper.dart';
import '../../journal/journal_cache_helper.dart';

enum SyncStatus { idle, syncing, success, error }

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
  final SupabaseDatasource _remoteDs;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSync;

  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncStateStream => _syncStateController.stream;

  SyncManager(this._localDb, this._remoteDs) {
    debugPrint('SyncManager: created, initializing listeners');
    _initConnectivityListener();
    _initPeriodicSync();
    // Trigger initial sync after a short delay to let auth settle
    Future.delayed(const Duration(seconds: 1), () async {
      // Fix legacy tasks: re-map projectId and re-mark for sync
      final tasks = await _localDb.getAllTasks();
      for (final t in tasks) {
        if (t.projectId == 'default-project') {
          await _localDb.customStatement(
            'UPDATE tasks SET project_id = \'00000000-0000-0000-0000-000000000001\', pending_sync = 1 WHERE id = \'${t.id}\'',
          );
        }
      }
      debugPrint('SyncManager: triggering initial sync');
      syncAll();
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
      const Duration(minutes: 1),
      (_) => syncAll(),
    );
  }

  Future<void> syncAll() async {
    debugPrint('SyncManager.syncAll: starting');
    _syncStateController.add(const SyncState(status: SyncStatus.syncing));
    try {
      await _syncPendingChanges();
      await _pullRemoteChanges();
      debugPrint('SyncManager.syncAll: completed successfully');
      _syncStateController.add(SyncState(
        status: SyncStatus.success,
        lastSyncTime: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('SyncManager.syncAll: error - $e');
      _syncStateController.add(SyncState(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _syncPendingChanges() async {
    // Sync pending projects (skip the non-UUID default project from old installs)
    final pendingProjects = await _localDb.getPendingProjects();
    debugPrint('SyncManager._syncPendingChanges: ${pendingProjects.length} pending projects');
    for (final driftProject in pendingProjects) {
      // Skip legacy default project with non-UUID id
      if (driftProject.id == 'default-project') {
        debugPrint('SyncManager: skipping legacy default project');
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
    debugPrint('SyncManager._syncPendingChanges: ${pendingTasks.length} pending tasks');
    for (final driftTask in pendingTasks) {
      // Remap legacy default-project to fixed UUID
      final fixedProjectId = driftTask.projectId == 'default-project'
          ? '00000000-0000-0000-0000-000000000001'
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
    debugPrint('SyncManager._syncPendingChanges: ${pendingTimeEntries.length} pending time entries');
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
    debugPrint('SyncManager._pullRemoteChanges: ${remoteProjects.length} remote projects');
    // Only keep one default project (prefer the fixed UUID)
    final List<Map<String, dynamic>> filtered = [];
    bool hasFixedDefault = false;
    for (final p in remoteProjects) {
      final isDefault = (p['name'] as String?)?.toLowerCase() == 'default' || (p['is_default'] as bool?) == true;
      if (isDefault) {
        if (p['id'] == '00000000-0000-0000-0000-000000000001') {
          hasFixedDefault = true;
          filtered.add(p);
        } else if (!hasFixedDefault) {
          filtered.add(p);
          hasFixedDefault = true;
        }
      } else {
        filtered.add(p);
      }
    }
    for (final p in filtered) {
      await _localDb.upsertProjectFromRemote(p);
    }

    final remoteTasks = await _remoteDs.fetchTasks();
    debugPrint('SyncManager._pullRemoteChanges: ${remoteTasks.length} remote tasks');
    for (final t in remoteTasks) {
      await _localDb.upsertTaskFromRemote(t);
    }

    final remoteTimeEntries = await _remoteDs.fetchTimeEntries();
    debugPrint('SyncManager._pullRemoteChanges: ${remoteTimeEntries.length} remote time entries');
    for (final e in remoteTimeEntries) {
      await _localDb.upsertTimeEntryFromRemote(e);
    }

    // Special Days (stored in Supabase, cached in SharedPreferences)
    try {
      final specialDaysRaw = await _remoteDs.fetchSpecialDays();
      if (specialDaysRaw.isNotEmpty) {
        debugPrint('SyncManager._pullRemoteChanges: ${specialDaysRaw.length} special days from remote');
        SpecialDaysCacheHelper.mergeRemoteData(specialDaysRaw);
      }
    } catch (e) {
      debugPrint('SyncManager._pullRemoteChanges: special days sync failed — $e');
    }

    // Journal Entries (stored in Supabase, cached in SharedPreferences)
    try {
      final journalRaw = await _remoteDs.fetchJournalEntries();
      if (journalRaw.isNotEmpty) {
        debugPrint('SyncManager._pullRemoteChanges: ${journalRaw.length} journal entries from remote');
        JournalCacheHelper.mergeRemoteData(journalRaw);
      }
    } catch (e) {
      debugPrint('SyncManager._pullRemoteChanges: journal sync failed — $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSync?.cancel();
    _syncStateController.close();
  }
}
