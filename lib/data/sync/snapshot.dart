/// In-memory shape of the WebDAV snapshot.
///
/// Each collection is a list of plain JSON maps — exactly the same shape
/// `SnapshotCodec` reads from / writes to Drift / SharedPreferences. The
/// remote schema lives entirely in JSON, which keeps the on-disk format
/// forward-compatible: adding a new field on either side never breaks
/// decoding the other.
///
/// `schemaVersion` is bumped whenever the JSON layout changes in a way
/// that requires a migration. Currently at v1 (no user_id, single user).
library;

class SyncSnapshot {
  SyncSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    this.projects = const [],
    this.tasks = const [],
    this.timeEntries = const [],
    Map<String, List<Map<String, dynamic>>>? journal,
    Map<String, List<String>>? moods,
    Map<String, Map<String, String>>? specialDays,
  })  : journal = journal ?? const {},
        moods = moods ?? const {},
        specialDays = specialDays ?? const {};

  /// Bumped whenever the on-disk shape changes incompatibly.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime exportedAt;

  /// Project rows, in the same snake_case shape the Appwrite schema used.
  /// Maps to the Drift `projects` table.
  final List<Map<String, dynamic>> projects;

  /// Task rows. Maps to the Drift `tasks` table.
  final List<Map<String, dynamic>> tasks;

  /// Time-entry rows. Maps to the Drift `time_entries` table.
  final List<Map<String, dynamic>> timeEntries;

  /// Journal entries, keyed by date_key. Maps to the SharedPreferences
  /// `journal_cache` value (a map of dateKey → list of entry JSON).
  final Map<String, List<Map<String, dynamic>>> journal;

  /// Moods keyed by date_key. Maps to the SharedPreferences
  /// `mood_cache` value (a map of dateKey → list of emoji strings).
  final Map<String, List<String>> moods;

  /// Special days keyed by date_key. Maps to the SharedPreferences
  /// `special_days_cache` value (a map of dateKey → {color, description}).
  final Map<String, Map<String, String>> specialDays;

  bool get isEmpty =>
      projects.isEmpty &&
      tasks.isEmpty &&
      timeEntries.isEmpty &&
      journal.isEmpty &&
      moods.isEmpty &&
      specialDays.isEmpty;
}
