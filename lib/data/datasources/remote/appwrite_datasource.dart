import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
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
  final Client _client;
  final String userId;
  final String databaseId;

  AppwriteDatasource(this._client, this.userId, this.databaseId);

  Databases get _databases => Databases(_client);

  // Projects
  @override
  Future<List<Map<String, dynamic>>> fetchProjects() async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: 'projects',
      queries: [
        Query.equal('user_id', userId),
        Query.isNull('deleted_at'),
        Query.orderAsc(r'$createdAt'),
      ],
    );
    return result.documents.map(_projectDocToMap).toList();
  }

  @override
  Future<void> upsertProject(Project project, {DateTime? deletedAt}) async {
    final data = _projectPayload(project, deletedAt: deletedAt);
    try {
      await _databases.createDocument(
        databaseId: databaseId,
        collectionId: 'projects',
        documentId: project.id,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        // Document already exists — fall back to update.
        await _databases.updateDocument(
          databaseId: databaseId,
          collectionId: 'projects',
          documentId: project.id,
          data: data,
        );
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    await _databases.updateDocument(
      databaseId: databaseId,
      collectionId: 'projects',
      documentId: id,
      data: {'deleted_at': DateTime.now().toIso8601String()},
    );
  }

  /// Build the project data map. Note: `createdAt` / `updatedAt` are
  /// auto-managed by Appwrite as `$createdAt` / `$updatedAt`; we never send
  /// them in the payload.
  Map<String, dynamic> _projectPayload(Project project, {DateTime? deletedAt}) {
    final data = <String, dynamic>{
      'user_id': userId,
      'parent_id': project.parentId,
      'name': project.name,
      'description': project.description,
      'color': project.color,
      'icon': project.icon,
      'start_date': project.startDate?.toIso8601String(),
      'end_date': project.endDate?.toIso8601String(),
      'sort_order': project.sortOrder,
      'is_default': project.isDefault,
    };
    if (deletedAt != null) {
      data['deleted_at'] = deletedAt.toIso8601String();
    }
    return data;
  }

  /// Project the Appwrite `Document` back to the row shape that downstream
  /// repositories already expect (snake_case + `id` field).
  Map<String, dynamic> _projectDocToMap(Document doc) {
    final data = Map<String, dynamic>.from(doc.data);
    data['id'] = doc.$id;
    data['created_at'] = doc.$createdAt.toIso8601String();
    data['updated_at'] = doc.$updatedAt.toIso8601String();
    return data;
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
