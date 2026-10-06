/// Backend-agnostic remote datasource contract.
///
/// After the Appwrite removal, the only implementation is [NoopRemote].
/// The interface is kept around because:
///   1. The repository / UI layers still accept a [RemoteDatasource]
///      on write paths; renaming them would touch many files for no
///      functional gain.
///   2. A future WebDAV-direct-write code path (if ever introduced)
///      could implement this without churning consumers.
library;

abstract class RemoteDatasource {
  /// Current user id, or null if the local-only path is in use.
  String? get userId;

  // Projects
  Future<List<Map<String, dynamic>>> fetchProjects();
  Future<void> upsertProject(Map<String, dynamic> data);
  Future<void> deleteProject(String id);

  // Tasks
  Future<List<Map<String, dynamic>>> fetchTasks();
  Future<void> upsertTask(Map<String, dynamic> data, {DateTime? deletedAt});
  Future<void> deleteTask(String id);

  // Time entries
  Future<List<Map<String, dynamic>>> fetchTimeEntries();
  Future<void> upsertTimeEntry(Map<String, dynamic> data);
  Future<void> deleteTimeEntry(String id);

  // Journal
  Future<List<Map<String, dynamic>>> fetchJournalEntries();
  Future<void> upsertJournalEntry(String dateKey, Map<String, dynamic> entry);
  Future<void> deleteJournalEntry(String entryId);

  // Moods
  Future<List<Map<String, dynamic>>> fetchMoods();
  Future<void> upsertMood(String dateKey, String data);
  Future<void> deleteMood(String dateKey);

  // Special days
  Future<List<Map<String, dynamic>>> fetchSpecialDays();
  Future<void> upsertSpecialDay(String dateKey, String data);
  Future<void> deleteSpecialDay(String dateKey);

  /// Live change feed for [name] (projects/tasks/…). WebDAV has no
  /// push, so the only implementation is the no-op default.
  Stream<List<Map<String, dynamic>>> watchCollection(String name);
}

/// No-op [RemoteDatasource]. Cloud writes are out of scope after the
/// Appwrite removal — the WebDAV [SyncEngine] owns all synchronization
/// on its own schedule. Repository / UI layers still pass a remote
/// argument on every write path; this stub keeps them compiling and
/// is silent in practice.
class NoopRemote implements RemoteDatasource {
  const NoopRemote();

  @override
  String? get userId => null;

  // Projects
  @override
  Future<List<Map<String, dynamic>>> fetchProjects() async => const [];

  @override
  Future<void> upsertProject(Map<String, dynamic> data) async {}

  @override
  Future<void> deleteProject(String id) async {}

  // Tasks
  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async => const [];

  @override
  Future<void> upsertTask(Map<String, dynamic> data,
      {DateTime? deletedAt}) async {}

  @override
  Future<void> deleteTask(String id) async {}

  // Time entries
  @override
  Future<List<Map<String, dynamic>>> fetchTimeEntries() async => const [];

  @override
  Future<void> upsertTimeEntry(Map<String, dynamic> data) async {}

  @override
  Future<void> deleteTimeEntry(String id) async {}

  // Journal
  @override
  Future<List<Map<String, dynamic>>> fetchJournalEntries() async => const [];

  @override
  Future<void> upsertJournalEntry(
    String dateKey,
    Map<String, dynamic> entry,
  ) async {}

  @override
  Future<void> deleteJournalEntry(String entryId) async {}

  // Moods
  @override
  Future<List<Map<String, dynamic>>> fetchMoods() async => const [];

  @override
  Future<void> upsertMood(String dateKey, String data) async {}

  @override
  Future<void> deleteMood(String dateKey) async {}

  // Special days
  @override
  Future<List<Map<String, dynamic>>> fetchSpecialDays() async => const [];

  @override
  Future<void> upsertSpecialDay(String dateKey, String data) async {}

  @override
  Future<void> deleteSpecialDay(String dateKey) async {}

  // Realtime — never used, kept for interface completeness.
  @override
  Stream<List<Map<String, dynamic>>> watchCollection(String name) =>
      const Stream.empty();
}

/// Factory kept for source compatibility with the previous
/// `buildRemoteDatasource(userId: …)` callsite. Returns a [NoopRemote]
/// regardless of inputs.
RemoteDatasource buildRemoteDatasource({String? userId}) => const NoopRemote();
