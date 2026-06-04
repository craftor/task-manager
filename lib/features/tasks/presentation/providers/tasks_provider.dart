import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/repositories/task_repository_impl.dart';
import '../../../../domain/entities/task.dart' show Task, Priority, TaskStatus;
import '../../../../domain/repositories/task_repository.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart' show remoteDatasourceProvider;

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider), ref.watch(remoteDatasourceProvider));
});

final tasksProvider = StreamNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

final selectedTaskIdProvider = StateProvider<String?>((ref) => null);

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

    // Reorder within the given sublist
    final reorderedSublist = List<Task>.from(tasks);
    final item = reorderedSublist.removeAt(oldIndex);
    reorderedSublist.insert(newIndex, item);

    // Reassign sortOrder globally: pending first, then completed
    final repository = ref.read(taskRepositoryProvider);
    final allTasks = await repository.getAllTasks();
    final reorderedIds = reorderedSublist.map((t) => t.id).toSet();

    final pendingTasks = reorderedSublist.where((t) => t.status != TaskStatus.completed).toList();
    final otherCompleted = allTasks
        .where((t) => !reorderedIds.contains(t.id) && t.status == TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final sortedCompleted = reorderedSublist
        .where((t) => t.status == TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    var sortIdx = 0;
    for (final t in pendingTasks) {
      await repository.updateTask(t.copyWith(sortOrder: sortIdx++, updatedAt: DateTime.now()));
    }
    for (final t in sortedCompleted) {
      await repository.updateTask(t.copyWith(sortOrder: sortIdx++, updatedAt: DateTime.now()));
    }
    for (final t in otherCompleted) {
      await repository.updateTask(t.copyWith(sortOrder: sortIdx++, updatedAt: DateTime.now()));
    }
  }
}
