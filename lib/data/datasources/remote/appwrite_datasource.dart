import 'package:appwrite/appwrite.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/time_entry.dart';
import 'remote_datasource.dart';

/// Appwrite implementation of [RemoteDatasource].
///
/// All methods currently throw [UnimplementedError] — this skeleton is the
/// target for the Phase C sub-steps. Once each method group is implemented
/// (C.1 projects, C.2 tasks, C.3 time_entries, C.4 special_days + moods,
/// C.5 journal_entries), flip `kUseAppwrite` in `remote_datasource_factory.dart`
/// to actually route here.
///
/// All queries must include `Query.equal('user_id', userId)` since Appwrite
/// self-hosted has no native row-level RLS — every collection permission is
/// set to "User" with full CRUD in the console.
class AppwriteDatasource implements RemoteDatasource {
  // ignore: unused_field
  final Client _client;
  final String userId;
  final String databaseId;

  AppwriteDatasource(this._client, this.userId, this.databaseId);

  // Projects
  @override
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    throw UnimplementedError('AppwriteDatasource.fetchProjects (Phase C.1)');
  }

  @override
  Future<void> upsertProject(Project project, {DateTime? deletedAt}) async {
    throw UnimplementedError('AppwriteDatasource.upsertProject (Phase C.1)');
  }

  @override
  Future<void> deleteProject(String id) async {
    throw UnimplementedError('AppwriteDatasource.deleteProject (Phase C.1)');
  }

  // Tasks
  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    throw UnimplementedError('AppwriteDatasource.fetchTasks (Phase C.2)');
  }

  @override
  Future<void> upsertTask(Task task, {DateTime? deletedAt}) async {
    throw UnimplementedError('AppwriteDatasource.upsertTask (Phase C.2)');
  }

  @override
  Future<void> deleteTask(String id) async {
    throw UnimplementedError('AppwriteDatasource.deleteTask (Phase C.2)');
  }

  // Time Entries
  @override
  Future<List<Map<String, dynamic>>> fetchTimeEntries() async {
    throw UnimplementedError(
        'AppwriteDatasource.fetchTimeEntries (Phase C.3)');
  }

  @override
  Future<void> upsertTimeEntry(TimeEntry entry) async {
    throw UnimplementedError(
        'AppwriteDatasource.upsertTimeEntry (Phase C.3)');
  }

  @override
  Future<void> deleteTimeEntry(String id) async {
    throw UnimplementedError(
        'AppwriteDatasource.deleteTimeEntry (Phase C.3)');
  }

  // Special Days
  @override
  Future<List<Map<String, dynamic>>> fetchSpecialDays() async {
    throw UnimplementedError(
        'AppwriteDatasource.fetchSpecialDays (Phase C.4)');
  }

  @override
  Future<void> upsertSpecialDay(String dateKey, String data) async {
    throw UnimplementedError(
        'AppwriteDatasource.upsertSpecialDay (Phase C.4)');
  }

  @override
  Future<void> deleteSpecialDay(String dateKey) async {
    throw UnimplementedError(
        'AppwriteDatasource.deleteSpecialDay (Phase C.4)');
  }

  // Moods
  @override
  Future<List<Map<String, dynamic>>> fetchMoods() async {
    throw UnimplementedError('AppwriteDatasource.fetchMoods (Phase C.4)');
  }

  @override
  Future<void> upsertMood(String dateKey, String data) async {
    throw UnimplementedError('AppwriteDatasource.upsertMood (Phase C.4)');
  }

  @override
  Future<void> deleteMood(String dateKey) async {
    throw UnimplementedError('AppwriteDatasource.deleteMood (Phase C.4)');
  }

  // Journal Entries
  @override
  Future<List<Map<String, dynamic>>> fetchJournalEntries() async {
    throw UnimplementedError(
        'AppwriteDatasource.fetchJournalEntries (Phase C.5)');
  }

  @override
  Future<void> upsertJournalEntry(
      String dateKey, Map<String, dynamic> entry) async {
    throw UnimplementedError(
        'AppwriteDatasource.upsertJournalEntry (Phase C.5)');
  }

  @override
  Future<void> deleteJournalEntry(String entryId) async {
    throw UnimplementedError(
        'AppwriteDatasource.deleteJournalEntry (Phase C.5)');
  }
}
