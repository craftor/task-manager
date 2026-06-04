import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/datasources/local/app_database.dart' show AppDatabase;
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/entities/project.dart';
import '../../../../domain/repositories/project_repository.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart' show remoteDatasourceProvider;

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(ref.watch(databaseProvider), ref.watch(remoteDatasourceProvider));
});

final projectsProvider =
    StreamNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

final selectedProjectIdProvider = StateProvider<String?>((ref) => null);

class ProjectsNotifier extends StreamNotifier<List<Project>> {
  @override
  Stream<List<Project>> build() {
    return ref.watch(projectRepositoryProvider).watchAllProjects();
  }

  Future<void> ensureDefaultProject() async {
    final repository = ref.read(projectRepositoryProvider);
    final existing = await repository.getProjectById(AppConstants.defaultProjectId);
    if (existing != null) return;

    // Also check by isDefault/name for legacy data
    final projects = await repository.getAllProjects();
    final hasLegacyDefault = projects.any((p) => p.isDefault || p.name == 'Default');
    if (hasLegacyDefault) return;

    final defaultProject = Project(
      id: AppConstants.defaultProjectId,
      name: 'Default',
      description: 'Default project for uncategorized tasks',
      color: '#808080',
      icon: 'folder',
      createdAt: DateTime.now(),
      isDefault: true,
      sortOrder: -1,
    );
    await repository.createProject(defaultProject);
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
    final projects = await repository.getAllProjects();
    final maxSortOrder = projects.isEmpty ? 0 : projects.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b);
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
      sortOrder: maxSortOrder + 1,
    );
    await repository.createProject(project);
  }

  Future<void> updateProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.updateProject(project);
  }

  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    final repository = ref.read(projectRepositoryProvider);
    final projects = await repository.getAllProjects();
    // Sort by sortOrder
    projects.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = projects.removeAt(oldIndex);
    projects.insert(newIndex, item);

    // Update all sort orders
    for (int i = 0; i < projects.length; i++) {
      final updated = projects[i].copyWith(sortOrder: i);
      await repository.updateProject(updated);
    }
  }

  Future<void> deleteProject(String id) async {
    final repository = ref.read(projectRepositoryProvider);
    final project = await repository.getProjectById(id);
    if (project == null) return;
    if (project.isDefault) return;
    await repository.deleteProject(id);
  }
}
