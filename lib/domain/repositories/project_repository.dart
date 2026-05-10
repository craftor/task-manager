import '../entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAllProjects();
  Stream<List<Project>> watchAllProjects();
  Future<Project?> getProjectById(String id);
  Future<void> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
}