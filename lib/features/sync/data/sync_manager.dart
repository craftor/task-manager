import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/datasources/remote/supabase_datasource.dart';
import '../../../../domain/entities/project.dart' as domain;

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
    _initConnectivityListener();
    _initPeriodicSync();
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
      const Duration(minutes: 5),
      (_) => syncAll(),
    );
  }

  Future<void> syncAll() async {
    _syncStateController.add(const SyncState(status: SyncStatus.syncing));
    try {
      await _syncPendingChanges();
      await _pullRemoteChanges();
      _syncStateController.add(SyncState(
        status: SyncStatus.success,
        lastSyncTime: DateTime.now(),
      ));
    } catch (e) {
      _syncStateController.add(SyncState(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _syncPendingChanges() async {
    // Sync pending projects
    final pendingProjects = await _localDb.getPendingProjects();
    for (final driftProject in pendingProjects) {
      final domainProject = domain.Project(
        id: driftProject.id,
        parentId: driftProject.parentId,
        name: driftProject.name,
        color: driftProject.color,
        icon: driftProject.icon,
        createdAt: driftProject.createdAt,
      );
      await _remoteDs.upsertProject(domainProject);
      await _localDb.markProjectSynced(driftProject.id);
    }
    // Similar for tasks and time entries
  }

  Future<void> _pullRemoteChanges() async {
    final remoteProjects = await _remoteDs.fetchProjects();
    for (final p in remoteProjects) {
      await _localDb.upsertProjectFromRemote(p);
    }
    // Similar for tasks and time entries
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSync?.cancel();
    _syncStateController.close();
  }
}
