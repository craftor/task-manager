import 'package:drift/drift.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../domain/time_entry_entity.dart' as entity;
import '../domain/time_entry_repository.dart';

class TimeEntryRepositoryImpl implements TimeEntryRepository {
  final AppDatabase _db;

  TimeEntryRepositoryImpl(this._db);

  @override
  Future<List<entity.TimeEntry>> getAllTimeEntries() async {
    final entries = await _db.getAllTimeEntries();
    return entries.map(_mapToEntity).toList();
  }

  @override
  Stream<List<entity.TimeEntry>> watchAllTimeEntries() {
    return _db.watchAllTimeEntries().map(
          (entries) => entries.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<List<entity.TimeEntry>> getTimeEntriesByTask(String taskId) async {
    final entries = await _db.getTimeEntriesByTask(taskId);
    return entries.map(_mapToEntity).toList();
  }

  @override
  Future<void> createTimeEntry(entity.TimeEntry entry) async {
    await _db.insertTimeEntry(
      TimeEntriesCompanion(
        id: Value(entry.id),
        taskId: Value(entry.taskId),
        startTime: Value(entry.startTime),
        endTime: Value(entry.endTime),
        durationMinutes: Value(entry.durationMinutes),
        note: Value(entry.note),
        manual: Value(entry.manual),
      ),
    );
  }

  @override
  Future<void> updateTimeEntry(entity.TimeEntry entry) async {
    await _db.updateTimeEntry(
      TimeEntriesCompanion(
        id: Value(entry.id),
        taskId: Value(entry.taskId),
        startTime: Value(entry.startTime),
        endTime: Value(entry.endTime),
        durationMinutes: Value(entry.durationMinutes),
        note: Value(entry.note),
        manual: Value(entry.manual),
        pendingSync: const Value(true),
      ),
    );
  }

  @override
  Future<void> deleteTimeEntry(String id) async {
    await _db.deleteTimeEntry(id);
  }

  entity.TimeEntry _mapToEntity(TimeEntry dbEntry) {
    return entity.TimeEntry(
      id: dbEntry.id,
      taskId: dbEntry.taskId,
      startTime: dbEntry.startTime,
      endTime: dbEntry.endTime,
      durationMinutes: dbEntry.durationMinutes,
      note: dbEntry.note,
      manual: dbEntry.manual,
    );
  }
}
