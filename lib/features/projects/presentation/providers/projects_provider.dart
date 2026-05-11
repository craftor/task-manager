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

  Future<void> createProject({
    String? parentId,
    required String name,
    required String color,
    required String icon,
  }) async {
    final repository = ref.read(projectRepositoryProvider);
    final project = Project(
      id: const Uuid().v4(),
      parentId: parentId,
      name: name,
      color: color,
      icon: icon,
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
    await repository.deleteProject(id);
  }
}
