import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/repositories/task_repository_impl.dart';
import '../../../../domain/entities/task.dart' show Task, Priority, TaskStatus;
import '../../../../domain/repositories/task_repository.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart' show supabaseDatasourceProvider;

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider), ref.watch(supabaseDatasourceProvider));
});

final tasksProvider = StreamNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

class TasksNotifier extends StreamNotifier<List<Task>> {
  @override
  Stream<List<Task>> build() {
    return ref.watch(taskRepositoryProvider).watchAllTasks();
  }

  Future<void> createTask({
    required String projectId,
    String? parentTaskId,
    required String title,
    String description = '',
    Priority priority = Priority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    List<String> tags = const [],
    int? estimatedMinutes,
    bool isRecurring = false,
    String? recurringRule,
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      projectId: projectId,
      parentTaskId: parentTaskId,
      title: title,
      description: description,
      priority: priority,
      status: TaskStatus.pending,
      startDate: startDate,
      dueDate: dueDate,
      tags: tags,
      estimatedMinutes: estimatedMinutes,
      isRecurring: isRecurring,
      recurringRule: recurringRule,
      createdAt: now,
      updatedAt: now,
    );
    await repository.createTask(task);
  }

  Future<void> updateTask(Task task) async {
    final repository = ref.read(taskRepositoryProvider);
    final updatedTask = task.copyWith(updatedAt: DateTime.now());
    await repository.updateTask(updatedTask);
  }

  Future<void> deleteTask(String id) async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.deleteTask(id);
  }

  Future<void> toggleTaskStatus(String id) async {
    final repository = ref.read(taskRepositoryProvider);
    final task = await repository.getTaskById(id);
    if (task != null) {
      final newStatus = task.status == TaskStatus.completed
          ? TaskStatus.pending
          : TaskStatus.completed;
      final updatedTask = task.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await repository.updateTask(updatedTask);
    }
  }

  Future<void> reorderTasks(List<Task> tasks, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Create a copy to avoid mutating the UI state directly
    final reordered = List<Task>.from(tasks);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    final repository = ref.read(taskRepositoryProvider);
    for (int i = 0; i < reordered.length; i++) {
      final updated = reordered[i].copyWith(sortOrder: i);
      await repository.updateTask(updated);
    }
  }
}
