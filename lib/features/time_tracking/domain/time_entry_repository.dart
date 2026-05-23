import 'time_entry_entity.dart';

abstract class TimeEntryRepository {
  Future<List<TimeEntry>> getAllTimeEntries();
  Stream<List<TimeEntry>> watchAllTimeEntries();
  Future<List<TimeEntry>> getTimeEntriesByTask(String taskId);
  Future<TimeEntry?> getTimeEntryById(String id);
  Future<void> createTimeEntry(TimeEntry entry);
  Future<void> updateTimeEntry(TimeEntry entry);
  Future<void> deleteTimeEntry(String id);
}
