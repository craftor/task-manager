import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:task_manager/core/constants/app_constants.dart';
import 'package:task_manager/domain/entities/project.dart';
import 'package:task_manager/domain/repositories/project_repository.dart';
import 'package:task_manager/features/projects/presentation/providers/projects_provider.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockProjectRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(Project(
      id: 'fallback',
      name: 'fallback',
      color: '#000000',
      icon: 'fallback',
      createdAt: DateTime(2020),
    ));
  });

  setUp(() {
    mockRepo = MockProjectRepository();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  }

  group('ProjectsNotifier', () {
    group('ensureDefaultProject', () {
      test('does nothing when default project already exists', () async {
        final existingDefault = Project(
          id: AppConstants.defaultProjectId,
          name: 'Default',
          color: '#808080',
          icon: 'folder',
          createdAt: DateTime(2026, 5, 1),
          isDefault: true,
          sortOrder: -1,
        );
        when(() => mockRepo.getProjectById(AppConstants.defaultProjectId))
            .thenAnswer((_) async => existingDefault);
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.ensureDefaultProject();

        verifyNever(() => mockRepo.createProject(any()));
      });

      test('does nothing when legacy default exists by name', () async {
        final legacy = Project(
          id: 'legacy-id',
          name: 'Default',
          color: '#808080',
          icon: 'folder',
          createdAt: DateTime(2026, 5, 1),
        );
        when(() => mockRepo.getProjectById(AppConstants.defaultProjectId))
            .thenAnswer((_) async => null);
        when(() => mockRepo.getAllProjects()).thenAnswer((_) async => [legacy]);
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.ensureDefaultProject();

        verifyNever(() => mockRepo.createProject(any()));
      });

      test('does nothing when legacy default exists by isDefault flag', () async {
        final legacy = Project(
          id: 'legacy-id',
          name: 'Work',
          color: '#333333',
          icon: 'briefcase',
          createdAt: DateTime(2026, 5, 1),
          isDefault: true,
        );
        when(() => mockRepo.getProjectById(AppConstants.defaultProjectId))
            .thenAnswer((_) async => null);
        when(() => mockRepo.getAllProjects()).thenAnswer((_) async => [legacy]);
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.ensureDefaultProject();

        verifyNever(() => mockRepo.createProject(any()));
      });

      test('creates default project when none exists', () async {
        when(() => mockRepo.getProjectById(AppConstants.defaultProjectId))
            .thenAnswer((_) async => null);
        when(() => mockRepo.getAllProjects()).thenAnswer((_) async => []);
        when(() => mockRepo.createProject(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.ensureDefaultProject();

        final captured = verify(() => mockRepo.createProject(captureAny())).captured.first as Project;
        expect(captured.id, AppConstants.defaultProjectId);
        expect(captured.name, 'Default');
        expect(captured.isDefault, true);
        expect(captured.sortOrder, -1);
      });
    });

    group('createProject', () {
      test('creates project with incremented sortOrder', () async {
        final existing = Project(
          id: 'existing-1',
          name: 'Existing',
          color: '#FF0000',
          icon: 'star',
          createdAt: DateTime(2026, 5, 1),
          sortOrder: 5,
        );
        when(() => mockRepo.getAllProjects()).thenAnswer((_) async => [existing]);
        when(() => mockRepo.createProject(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.createProject(
          name: 'New Project',
          color: '#3366FF',
          icon: 'rocket',
        );

        final captured = verify(() => mockRepo.createProject(captureAny())).captured.first as Project;
        expect(captured.name, 'New Project');
        expect(captured.color, '#3366FF');
        expect(captured.icon, 'rocket');
        expect(captured.sortOrder, 6); // max(5) + 1
        expect(captured.id.isNotEmpty, true);
      });

      test('creates project with sortOrder 0 when no projects exist', () async {
        when(() => mockRepo.getAllProjects()).thenAnswer((_) async => []);
        when(() => mockRepo.createProject(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.createProject(
          name: 'First Project',
          color: '#00FF00',
          icon: 'home',
        );

        final captured = verify(() => mockRepo.createProject(captureAny())).captured.first as Project;
        expect(captured.sortOrder, 0); // empty list → sortOrder 0
      });
    });

    test('updateProject calls repository.updateProject', () async {
      final project = Project(
        id: 'proj-1',
        name: 'Test',
        color: '#808080',
        icon: 'folder',
        createdAt: DateTime(2026, 5, 1),
      );
      when(() => mockRepo.updateProject(any())).thenAnswer((_) async {});
      when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

      final container = createContainer();
      final notifier = container.read(projectsProvider.notifier);

      await notifier.updateProject(project);

      verify(() => mockRepo.updateProject(project)).called(1);
    });

    group('deleteProject', () {
      test('deletes project by id', () async {
        final project = Project(
          id: 'proj-1',
          name: 'Test',
          color: '#808080',
          icon: 'folder',
          createdAt: DateTime(2026, 5, 1),
        );
        when(() => mockRepo.getProjectById('proj-1')).thenAnswer((_) async => project);
        when(() => mockRepo.deleteProject('proj-1')).thenAnswer((_) async {});
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.deleteProject('proj-1');

        verify(() => mockRepo.deleteProject('proj-1')).called(1);
      });

      test('does not delete default project', () async {
        final defaultProject = Project(
          id: AppConstants.defaultProjectId,
          name: 'Default',
          color: '#808080',
          icon: 'folder',
          createdAt: DateTime(2026, 5, 1),
          isDefault: true,
        );
        when(() => mockRepo.getProjectById(AppConstants.defaultProjectId))
            .thenAnswer((_) async => defaultProject);
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.deleteProject(AppConstants.defaultProjectId);

        verifyNever(() => mockRepo.deleteProject(any()));
      });

      test('does nothing when project does not exist', () async {
        when(() => mockRepo.getProjectById('nonexistent')).thenAnswer((_) async => null);
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        await notifier.deleteProject('nonexistent');

        verifyNever(() => mockRepo.deleteProject(any()));
      });
    });

    group('reorderProjects', () {
      test('reassigns sort orders after reorder', () async {
        final p1 = Project(id: 'p1', name: 'A', color: '#111', icon: 'a', createdAt: DateTime(2026, 5, 1), sortOrder: 0);
        final p2 = Project(id: 'p2', name: 'B', color: '#222', icon: 'b', createdAt: DateTime(2026, 5, 1), sortOrder: 1);
        final p3 = Project(id: 'p3', name: 'C', color: '#333', icon: 'c', createdAt: DateTime(2026, 5, 1), sortOrder: 2);

        when(() => mockRepo.getAllProjects()).thenAnswer((_) async => [p1, p2, p3]);
        when(() => mockRepo.updateProject(any())).thenAnswer((_) async {});
        when(() => mockRepo.watchAllProjects()).thenAnswer((_) => const Stream.empty());

        final container = createContainer();
        final notifier = container.read(projectsProvider.notifier);

        // Move p3 to index 0
        await notifier.reorderProjects(2, 0);

        final captured = verify(() => mockRepo.updateProject(captureAny())).captured;
        final updatedProjects = captured.map((c) => c as Project).toList();

        final sortOrders = <String, int>{};
        for (final p in updatedProjects) {
          sortOrders[p.id] = p.sortOrder;
        }
        expect(sortOrders['p3'], 0); // Moved to first
        expect(sortOrders['p1'], 1); // Shifted right
        expect(sortOrders['p2'], 2); // Shifted right
      });
    });
  });
}