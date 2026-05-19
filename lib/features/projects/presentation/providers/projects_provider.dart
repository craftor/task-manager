import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/datasources/local/app_database.dart' show AppDatabase;
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/entities/project.dart';
import '../../../../domain/repositories/project_repository.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart' show supabaseDatasourceProvider;

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(ref.watch(databaseProvider), ref.watch(supabaseDatasourceProvider));
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
    // Check by fixed ID, or by name/isDefault for legacy
    final hasDefault = projects.any((p) => p.id == AppConstants.defaultProjectId || p.isDefault || p.name == 'Default');
    if (!hasDefault) {
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
    final projects = await repository.getAllProjects();
    final project = projects.cast<Project?>().firstWhere((p) => p?.id == id, orElse: () => null);
    if (project == null) return;
    if (project.isDefault) return;
    await repository.deleteProject(id);
  }
}
