import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/task.dart' as entity;
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/remote/supabase_datasource.dart';

class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase _db;
  final SupabaseDatasource? _remote;

  TaskRepositoryImpl(this._db, [this._remote]);

  @override
  Future<List<entity.Task>> getAllTasks() async {
    try {
      final tasks = await _db.getAllTasks();
      debugPrint('TaskRepositoryImpl.getAllTasks: ${tasks.length} tasks');
      return tasks.map(_mapToEntity).toList();
    } catch (e) {
      debugPrint('TaskRepositoryImpl.getAllTasks error: $e');
      rethrow;
    }
  }

  @override
  Stream<List<entity.Task>> watchAllTasks() {
    return _db.watchAllTasks().map((tasks) {
      debugPrint('TaskRepositoryImpl.watchAllTasks: ${tasks.length} tasks');
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
      debugPrint('TaskRepositoryImpl.createTask: ${task.title}');
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
          debugPrint('TaskRepositoryImpl.createTask: synced to remote');
        }).catchError((e) {
          debugPrint('TaskRepositoryImpl.createTask remote push failed: $e');
        });
      }

      debugPrint('TaskRepositoryImpl.createTask: success');
    } catch (e) {
      debugPrint('TaskRepositoryImpl.createTask error: $e');
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
          debugPrint('TaskRepositoryImpl.updateTask: synced to remote');
        }).catchError((e) {
          debugPrint('TaskRepositoryImpl.updateTask remote push failed: $e');
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      // Get task data BEFORE deleting, to push a full upsert with deleted_at
      final dbTask = await _db.getTaskById(id);
      if (dbTask != null && _remote != null) {
        // Push full synced-delete via upsert (works with insert-only RLS)
        _remote!.upsertTask(entity.Task(
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
          updatedAt: DateTime.now(),
          sortOrder: dbTask.sortOrder,
        ), deletedAt: DateTime.now()).then((_) {
          debugPrint('TaskRepositoryImpl.deleteTask: pushed full sync-delete to remote');
        }).catchError((e) {
          debugPrint('TaskRepositoryImpl.deleteTask remote push failed: $e');
        });
      }

      // Then hard-delete locally
      await _db.deleteTask(id);
    } catch (e) {
      rethrow;
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
