import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAllTasks();
  Stream<List<Task>> watchAllTasks();
  Future<Task?> getTaskById(String id);
  Future<List<Task>> getTasksByProject(String projectId);
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
}