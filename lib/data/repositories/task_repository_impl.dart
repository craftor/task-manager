import 'package:drift/drift.dart';
import '../../../core/utils/logger.dart';
import '../../domain/entities/task.dart' as entity;
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/remote_datasource.dart';

class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase _db;
  final RemoteDatasource? _remote;

  TaskRepositoryImpl(this._db, [this._remote]);

  @override
  Future<List<entity.Task>> getAllTasks() async {
    try {
      final tasks = await _db.getAllTasks();
      Logger.d('TaskRepositoryImpl.getAllTasks: ${tasks.length} tasks');
      return tasks.map(_mapToEntity).toList();
    } catch (e) {
      Logger.d('TaskRepositoryImpl.getAllTasks error: $e');
      rethrow;
    }
  }

  @override
  Stream<List<entity.Task>> watchAllTasks() {
    return _db.watchAllTasks().map((tasks) {
      Logger.d('TaskRepositoryImpl.watchAllTasks: ${tasks.length} tasks');
      return tasks.map(_mapToEntity).toList();
    });
  }

  @override
  Future<entity.Task?> getTaskById(String id) async {
    try {
      final task = await _db.getTaskById(id);
      return task != null ? _mapToEntity(task) : null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<entity.Task>> getTasksByProject(String projectId) async {
    try {
      final tasks = await _db.getTasksByProject(projectId);
      return tasks.map(_mapToEntity).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> createTask(entity.Task task) async {
    try {
      Logger.d('TaskRepositoryImpl.createTask: ${task.title}');
      await _db.insertTask(TasksCompanion(
        id: Value(task.id),
        projectId: Value(task.projectId),
        parentTaskId: Value(task.parentTaskId),
        title: Value(task.title),
        description: Value(task.description),
        priority: Value(task.priority.index),
        status: Value(task.status.index),
        startDate: Value(task.startDate),
        dueDate: Value(task.dueDate),
        tags: Value(task.tags),
        estimatedMinutes: Value(task.estimatedMinutes),
        actualMinutes: Value(task.actualMinutes),
        isRecurring: Value(task.isRecurring),
        recurringRule: Value(task.recurringRule),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
        sortOrder: Value(task.sortOrder),
        pendingSync: const Value(true),
      ));

      // Push to remote immediately
      if (_remote != null) {
        _remote!.upsertTask(task).then((_) {
          Logger.d('TaskRepositoryImpl.createTask: synced to remote');
        }).catchError((e) {
          Logger.d('TaskRepositoryImpl.createTask remote push failed: $e');
        });
      }

      Logger.d('TaskRepositoryImpl.createTask: success');
    } catch (e) {
      Logger.d('TaskRepositoryImpl.createTask error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateTask(entity.Task task) async {
    try {
      await _db.updateTask(TasksCompanion(
        id: Value(task.id),
        projectId: Value(task.projectId),
        parentTaskId: Value(task.parentTaskId),
        title: Value(task.title),
        description: Value(task.description),
        priority: Value(task.priority.index),
        status: Value(task.status.index),
        startDate: Value(task.startDate),
        dueDate: Value(task.dueDate),
        tags: Value(task.tags),
        estimatedMinutes: Value(task.estimatedMinutes),
        actualMinutes: Value(task.actualMinutes),
        isRecurring: Value(task.isRecurring),
        recurringRule: Value(task.recurringRule),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
        sortOrder: Value(task.sortOrder),
        pendingSync: const Value(true),
      ));

      // Push to remote immediately
      if (_remote != null) {
        _remote!.upsertTask(task).then((_) {
          Logger.d('TaskRepositoryImpl.updateTask: synced to remote');
        }).catchError((e) {
          Logger.d('TaskRepositoryImpl.updateTask remote push failed: $e');
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    // Soft-delete: stamp deletedAt + pendingSync instead of physically
    // removing the row. SyncManager will push the soft-delete to the
    // remote and only then physical-delete locally on success. If the
    // user is offline, the tombstone survives the next pull.
    final dbTask = await _db.getTaskById(id);
    if (dbTask == null) return;

    await _db.updateTask(TasksCompanion(
      id: Value(dbTask.id),
      projectId: Value(dbTask.projectId),
      parentTaskId: Value(dbTask.parentTaskId),
      title: Value(dbTask.title),
      description: Value(dbTask.description),
      priority: Value(dbTask.priority),
      status: Value(dbTask.status),
      startDate: Value(dbTask.startDate),
      dueDate: Value(dbTask.dueDate),
      tags: Value(dbTask.tags),
      estimatedMinutes: Value(dbTask.estimatedMinutes),
      actualMinutes: Value(dbTask.actualMinutes),
      isRecurring: Value(dbTask.isRecurring),
      recurringRule: Value(dbTask.recurringRule),
      createdAt: Value(dbTask.createdAt),
      updatedAt: Value(DateTime.now()),
      sortOrder: Value(dbTask.sortOrder),
      deletedAt: Value(DateTime.now()),
      pendingSync: const Value(true),
    ));

    // Fire-and-forget push — the upsert carries the deletedAt timestamp,
    // Appwrite writes it, and on the next SyncManager tick the local
    // tombstone will be physically deleted after successful ack.
    if (_remote != null) {
      _remote!.upsertTask(_mapToEntity(dbTask), deletedAt: DateTime.now())
          .then((_) {
        Logger.d('TaskRepositoryImpl.deleteTask: tombstone pushed to remote');
      }).catchError((e) {
        Logger.d('TaskRepositoryImpl.deleteTask remote push failed: $e');
      });
    }
  }

  entity.Task _mapToEntity(Task dbTask) {
    return entity.Task(
      id: dbTask.id,
      projectId: dbTask.projectId,
      parentTaskId: dbTask.parentTaskId,
      title: dbTask.title,
      description: dbTask.description,
      priority: entity.Priority.values[dbTask.priority],
      status: entity.TaskStatus.values[dbTask.status],
      startDate: dbTask.startDate,
      dueDate: dbTask.dueDate,
      tags: dbTask.tags,
      estimatedMinutes: dbTask.estimatedMinutes,
      actualMinutes: dbTask.actualMinutes,
      isRecurring: dbTask.isRecurring,
      recurringRule: dbTask.recurringRule,
      createdAt: dbTask.createdAt,
      updatedAt: dbTask.updatedAt,
      sortOrder: dbTask.sortOrder,
    );
  }
}
