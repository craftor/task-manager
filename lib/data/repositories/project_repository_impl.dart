import 'package:drift/drift.dart';
import '../../domain/entities/project.dart' as entity;
import '../../domain/repositories/project_repository.dart';
import '../datasources/local/app_database.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final AppDatabase _db;

  ProjectRepositoryImpl(this._db);

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
      await _db.insertProject(
        ProjectsCompanion(
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
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateProject(entity.Project project) async {
    try {
      await _db.updateProject(
        ProjectsCompanion(
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
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    try {
      await _db.deleteProject(id);
    } catch (e) {
      rethrow;
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