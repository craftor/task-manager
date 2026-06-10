import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:task_manager/domain/entities/task.dart';
import 'package:task_manager/domain/repositories/task_repository.dart';
import 'package:task_manager/features/tasks/presentation/providers/tasks_provider.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(Task(
      id: 'fallback',
      projectId: 'fallback',
      title: 'fallback',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    ));
  });

  setUp(() {
    mockRepo = MockTaskRepository();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  }

  group('TasksNotifier', () {
    test('createTask calls repository.createTask with pending status and UUID', () async {
      when(() => mockRepo.createTask(any())).thenAnswer((_) async {});
      when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

      final container = createContainer();
      final notifier = container.read(tasksProvider.notifier);

      await notifier.createTask(
        projectId: 'proj-1',
        title: 'New Task',
        priority: Priority.high,
      );

      final captured = verify(() => mockRepo.createTask(captureAny())).captured.first as Task;
      expect(captured.projectId, 'proj-1');
      expect(captured.title, 'New Task');
      expect(captured.priority, Priority.high);
      expect(captured.status, TaskStatus.pending);
      expect(captured.id.isNotEmpty, true); // UUID was assigned
      expect(captured.createdAt, isNotNull);
      expect(captured.updatedAt, isNotNull);
    });

    test('createTask with tags and dueDate passes them through', () async {
      when(() => mockRepo.createTask(any())).thenAnswer((_) async {});
      when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

      final container = createContainer();
      final notifier = container.read(tasksProvider.notifier);
      final dueDate = DateTime(2026, 6, 1);

      await notifier.createTask(
        projectId: 'proj-1',
        title: 'Tagged Task',
        description: 'A description',
        tags: ['work', 'urgent'],
        dueDate: dueDate,
        estimatedMinutes: 60,
        isRecurring: true,
      );

      final captured = verify(() => mockRepo.createTask(captureAny())).captured.first as Task;
      expect(captured.tags, ['work', 'urgent']);
      expect(captured.dueDate, dueDate);
      expect(captured.estimatedMinutes, 60);
      expect(captured.isRecurring, true);
      expect(captured.description, 'A description');
    });

    test('updateTask calls repository with updated updatedAt', () async {
      when(() => mockRepo.updateTask(any())).thenAnswer((_) async {});
      when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

      final container = createContainer();
      final notifier = container.read(tasksProvider.notifier);
      final originalTask = Task(
        id: 'task-1',
        projectId: 'proj-1',
        title: 'Original',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );

      await notifier.updateTask(originalTask);

      final captured = verify(() => mockRepo.updateTask(captureAny())).captured.first as Task;
      expect(captured.title, 'Original');
      expect(captured.updatedAt.isAfter(originalTask.updatedAt), true);
    });

    test('deleteTask calls repository.deleteTask', () async {
      when(() => mockRepo.deleteTask(any())).thenAnswer((_) async {});
      when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

      final container = createContainer();
      final notifier = container.read(tasksProvider.notifier);

      await notifier.deleteTask('task-1');

      verify(() => mockRepo.deleteTask('task-1')).called(1);
    });

    group('toggleTaskStatus', () {
      test('toggles pending to completed', () async {
        final task = Task(
          id: 'task-1',
          projectId: 'proj-1',
          title: 'Toggle Me',
          status: TaskStatus.pending,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        );
        when(() => mockRepo.getTaskById('task-1')).thenAnswer((_) async => task);
        when(() => mockRepo.updateTask(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(tasksProvider.notifier);

        await notifier.toggleTaskStatus('task-1');

        final captured = verify(() => mockRepo.updateTask(captureAny())).captured.first as Task;
        expect(captured.status, TaskStatus.completed);
        expect(captured.updatedAt.isAfter(task.updatedAt), true);
      });

      test('toggles completed to pending', () async {
        final task = Task(
          id: 'task-1',
          projectId: 'proj-1',
          title: 'Un-toggle',
          status: TaskStatus.completed,
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        );
        when(() => mockRepo.getTaskById('task-1')).thenAnswer((_) async => task);
        when(() => mockRepo.updateTask(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(tasksProvider.notifier);

        await notifier.toggleTaskStatus('task-1');

        final captured = verify(() => mockRepo.updateTask(captureAny())).captured.first as Task;
        expect(captured.status, TaskStatus.pending);
      });

      test('does nothing when task is null', () async {
        when(() => mockRepo.getTaskById('nonexistent')).thenAnswer((_) async => null);
        when(() => mockRepo.updateTask(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(tasksProvider.notifier);

        await notifier.toggleTaskStatus('nonexistent');

        verifyNever(() => mockRepo.updateTask(any()));
      });
    });

    group('reorderTasks', () {
      test('reassigns sort orders correctly for pending-then-completed', () async {
        final pending1 = Task(
          id: 't1', projectId: 'p1', title: 'A', status: TaskStatus.pending,
          createdAt: DateTime(2026, 5, 1), updatedAt: DateTime(2026, 5, 1), sortOrder: 0,
        );
        final pending2 = Task(
          id: 't2', projectId: 'p1', title: 'B', status: TaskStatus.pending,
          createdAt: DateTime(2026, 5, 1), updatedAt: DateTime(2026, 5, 1), sortOrder: 1,
        );
        final done1 = Task(
          id: 't3', projectId: 'p1', title: 'C', status: TaskStatus.completed,
          createdAt: DateTime(2026, 5, 1), updatedAt: DateTime(2026, 5, 1), sortOrder: 2,
        );

        when(() => mockRepo.getAllTasks()).thenAnswer((_) async => [pending1, pending2, done1]);
        when(() => mockRepo.updateTask(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllTasks()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(tasksProvider.notifier);

        // Move t2 to index 0 (before t1)
        await notifier.reorderTasks([pending1, pending2, done1], 1, 0);

        // Capture all update calls
        final captured = verify(() => mockRepo.updateTask(captureAny())).captured;
        final updatedTasks = captured.map((c) => c as Task).toList();

        // Find the sort order mapping
        final sortOrders = <String, int>{};
        for (final t in updatedTasks) {
          sortOrders[t.id] = t.sortOrder;
        }
        expect(sortOrders['t2'], 0); // Moved to first
        expect(sortOrders['t1'], 1); // Original first became second
        expect(sortOrders['t3'], 2); // Completed stays last
      });
    });
  });
}