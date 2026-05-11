import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/repositories/task_repository_impl.dart';
import '../../../../domain/entities/task.dart' show Task, Priority, TaskStatus;
import '../../../../domain/repositories/task_repository.dart';
import '../../../projects/presentation/providers/projects_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider));
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
}
