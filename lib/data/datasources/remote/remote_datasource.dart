import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/time_entry.dart';

/// Backend-agnostic interface for the remote data source.
///
/// All cloud I/O (Appwrite, since the Supabase → Appwrite migration) flows
/// through this interface so feature code (services, repositories, screens)
/// stays unaware of the underlying SDK.
///
/// Implemented by [AppwriteDatasource] (replaces the deleted
/// SupabaseDatasource from Phase E).
abstract class RemoteDatasource {
  // Projects
  Future<List<Map<String, dynamic>>> fetchProjects();
  Future<void> upsertProject(Project project, {DateTime? deletedAt});
  Future<void> deleteProject(String id);

  // Tasks
  Future<List<Map<String, dynamic>>> fetchTasks();
  Future<void> upsertTask(Task task, {DateTime? deletedAt});
  Future<void> deleteTask(String id);

  // Time Entries
  Future<List<Map<String, dynamic>>> fetchTimeEntries();
  Future<void> upsertTimeEntry(TimeEntry entry);
  Future<void> deleteTimeEntry(String id);

  // Special Days
  Future<List<Map<String, dynamic>>> fetchSpecialDays();
  Future<void> upsertSpecialDay(String dateKey, String data);
  Future<void> deleteSpecialDay(String dateKey);

  // Moods
  Future<List<Map<String, dynamic>>> fetchMoods();
  Future<void> upsertMood(String dateKey, String data);
  Future<void> deleteMood(String dateKey);

  // Journal Entries
  Future<List<Map<String, dynamic>>> fetchJournalEntries();
  Future<void> upsertJournalEntry(String dateKey, Map<String, dynamic> entry);
  Future<void> deleteJournalEntry(String entryId);
}
