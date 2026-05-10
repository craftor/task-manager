import 'package:drift/drift.dart';
import '../../domain/entities/task.dart' as entity;
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/app_database.dart';

class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase _db;

  TaskRepositoryImpl(this._db);

  @override
  Future<List<entity.Task>> getAllTasks() async {
    final tasks = await _db.getAllTasks();
    return tasks.map(_mapToEntity).toList();
  }

  @override
  Stream<List<entity.Task>> watchAllTasks() {
    return _db.watchAllTasks().map(
          (tasks) => tasks.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<entity.Task?> getTaskById(String id) async {
    final task = await _db.getTaskById(id);
    return task != null ? _mapToEntity(task) : null;
  }

  @override
  Future<List<entity.Task>> getTasksByProject(String projectId) async {
    final tasks = await _db.getTasksByProject(projectId);
    return tasks.map(_mapToEntity).toList();
  }

  @override
  Future<void> createTask(entity.Task task) async {
    await _db.insertTask(
      TasksCompanion(
        id: Value(task.id),
        projectId: Value(task.projectId),
        parentTaskId: Value(task.parentTaskId),
        title: Value(task.title),
        description: Value(task.description),
        priority: Value(task.priority.index),
        status: Value(task.status.index),
        dueDate: Value(task.dueDate),
        tags: Value(task.tags.join(',')),  // Use join since we store as comma-separated
        estimatedMinutes: Value(task.estimatedMinutes),
        actualMinutes: Value(task.actualMinutes),
        isRecurring: Value(task.isRecurring),
        recurringRule: Value(task.recurringRule),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
      ),
    );
  }

  @override
  Future<void> updateTask(entity.Task task) async {
    await _db.updateTask(
      TasksCompanion(
        id: Value(task.id),
        projectId: Value(task.projectId),
        parentTaskId: Value(task.parentTaskId),
        title: Value(task.title),
        description: Value(task.description),
        priority: Value(task.priority.index),
        status: Value(task.status.index),
        dueDate: Value(task.dueDate),
        tags: Value(task.tags.join(',')),
        estimatedMinutes: Value(task.estimatedMinutes),
        actualMinutes: Value(task.actualMinutes),
        isRecurring: Value(task.isRecurring),
        recurringRule: Value(task.recurringRule),
        createdAt: Value(task.createdAt),
        updatedAt: Value(task.updatedAt),
      ),
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
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
      dueDate: dbTask.dueDate,
      tags: dbTask.tags.isEmpty ? [] : dbTask.tags.split(','),
      estimatedMinutes: dbTask.estimatedMinutes,
      actualMinutes: dbTask.actualMinutes,
      isRecurring: dbTask.isRecurring,
      recurringRule: dbTask.recurringRule,
      createdAt: dbTask.createdAt,
      updatedAt: dbTask.updatedAt,
    );
  }
}