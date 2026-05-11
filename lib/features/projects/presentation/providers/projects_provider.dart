import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/datasources/local/app_database.dart' show AppDatabase;
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/entities/project.dart';
import '../../../../domain/repositories/project_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(ref.watch(databaseProvider));
});

final projectsProvider =
    StreamNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

class ProjectsNotifier extends StreamNotifier<List<Project>> {
  @override
  Stream<List<Project>> build() {
    return ref.watch(projectRepositoryProvider).watchAllProjects();
  }

  Future<void> ensureDefaultProject() async {
    final repository = ref.read(projectRepositoryProvider);
    final projects = await repository.getAllProjects();
    final hasDefault = projects.any((p) => p.isDefault);
    if (!hasDefault) {
      final defaultProject = Project(
        id: 'default-project',
        name: 'Default',
        description: 'Default project for uncategorized tasks',
        color: '#808080',
        icon: 'folder',
        createdAt: DateTime.now(),
        isDefault: true,
      );
      await repository.createProject(defaultProject);
    }
  }

  Future<void> createProject({
    String? parentId,
    required String name,
    String? description,
    required String color,
    required String icon,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final repository = ref.read(projectRepositoryProvider);
    final project = Project(
      id: const Uuid().v4(),
      parentId: parentId,
      name: name,
      description: description,
      color: color,
      icon: icon,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );
    await repository.createProject(project);
  }

  Future<void> updateProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.updateProject(project);
  }

  Future<void> deleteProject(String id) async {
    final repository = ref.read(projectRepositoryProvider);
    final projects = await repository.getAllProjects();
    final project = projects.firstWhere((p) => p.id == id, orElse: () => throw Exception('Project not found'));
    if (project.isDefault) {
      return; // Cannot delete default project
    }
    await repository.deleteProject(id);
  }
}
