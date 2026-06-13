import 'package:drift/drift.dart';
import '../../../core/utils/logger.dart';
import '../../domain/entities/project.dart' as entity;
import '../../domain/repositories/project_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/remote_datasource.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final AppDatabase _db;
  final RemoteDatasource? _remote;

  ProjectRepositoryImpl(this._db, [this._remote]);

  @override
  Future<List<entity.Project>> getAllProjects() async {
    try {
      final projects = await _db.getAllProjects();
      return projects.map(_mapToEntity).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<entity.Project>> watchAllProjects() {
    return _db.watchAllProjects().map(
          (projects) => projects.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<entity.Project?> getProjectById(String id) async {
    try {
      final project = await _db.getProjectById(id);
      return project != null ? _mapToEntity(project) : null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> createProject(entity.Project project) async {
    try {
      await _db.insertProject(ProjectsCompanion(
        id: Value(project.id),
        parentId: Value(project.parentId),
        name: Value(project.name),
        description: Value(project.description),
        color: Value(project.color),
        icon: Value(project.icon),
        startDate: Value(project.startDate),
        endDate: Value(project.endDate),
        createdAt: Value(project.createdAt),
        sortOrder: Value(project.sortOrder),
        isDefault: Value(project.isDefault),
        pendingSync: const Value(true),
      ));

      // Push to remote immediately
      if (_remote != null) {
        _remote!.upsertProject(project).then((_) {
          Logger.d('ProjectRepositoryImpl.createProject: synced to remote');
        }).catchError((e) {
          Logger.d('ProjectRepositoryImpl.createProject remote push failed: $e');
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateProject(entity.Project project) async {
    try {
      await _db.updateProject(ProjectsCompanion(
        id: Value(project.id),
        parentId: Value(project.parentId),
        name: Value(project.name),
        description: Value(project.description),
        color: Value(project.color),
        icon: Value(project.icon),
        startDate: Value(project.startDate),
        endDate: Value(project.endDate),
        createdAt: Value(project.createdAt),
        sortOrder: Value(project.sortOrder),
        isDefault: Value(project.isDefault),
        pendingSync: const Value(true),
      ));

      // Push to remote immediately
      if (_remote != null) {
        _remote!.upsertProject(project).then((_) {
          Logger.d('ProjectRepositoryImpl.updateProject: synced to remote');
        }).catchError((e) {
          Logger.d('ProjectRepositoryImpl.updateProject remote push failed: $e');
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    // Soft-delete: stamp deletedAt + pendingSync instead of physically
    // removing the row. SyncManager pushes the tombstone and only then
    // physical-deletes locally after remote ack. Survives offline.
    final dbProject = await _db.getProjectById(id);
    if (dbProject == null) return;

    await _db.updateProject(ProjectsCompanion(
      id: Value(dbProject.id),
      parentId: Value(dbProject.parentId),
      name: Value(dbProject.name),
      description: Value(dbProject.description),
      color: Value(dbProject.color),
      icon: Value(dbProject.icon),
      startDate: Value(dbProject.startDate),
      endDate: Value(dbProject.endDate),
      createdAt: Value(dbProject.createdAt),
      sortOrder: Value(dbProject.sortOrder),
      isDefault: Value(dbProject.isDefault),
      deletedAt: Value(DateTime.now()),
      pendingSync: const Value(true),
    ));

    if (_remote != null) {
      _remote!.upsertProject(_mapToEntity(dbProject), deletedAt: DateTime.now())
          .then((_) {
        Logger.d('ProjectRepositoryImpl.deleteProject: tombstone pushed to remote');
      }).catchError((e) {
        Logger.d('ProjectRepositoryImpl.deleteProject remote push failed: $e');
      });
    }
  }

  entity.Project _mapToEntity(Project dbProject) {
    return entity.Project(
      id: dbProject.id,
      parentId: dbProject.parentId,
      name: dbProject.name,
      description: dbProject.description,
      color: dbProject.color,
      icon: dbProject.icon,
      startDate: dbProject.startDate,
      endDate: dbProject.endDate,
      createdAt: dbProject.createdAt,
      sortOrder: dbProject.sortOrder,
      isDefault: dbProject.isDefault,
    );
  }
}
