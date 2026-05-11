import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../data/time_entry_repository_impl.dart';
import '../../domain/time_entry_entity.dart';
import '../../domain/time_entry_repository.dart';

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  return TimeEntryRepositoryImpl(ref.watch(databaseProvider));
});

final timeEntriesProvider =
    StreamNotifierProvider<TimeEntriesNotifier, List<TimeEntry>>(
  TimeEntriesNotifier.new,
);

class TimeEntriesNotifier extends StreamNotifier<List<TimeEntry>> {
  Timer? _runningTimer;
  String? _runningEntryId;

  @override
  Stream<List<TimeEntry>> build() {
    ref.onDispose(() {
      _runningTimer?.cancel();
    });
    return ref.watch(timeEntryRepositoryProvider).watchAllTimeEntries();
  }

  Future<void> startTimer(String taskId) async {
    if (_runningEntryId != null) {
      await stopTimer();
    }

    final repository = ref.read(timeEntryRepositoryProvider);
    final entry = TimeEntry(
      id: const Uuid().v4(),
      taskId: taskId,
      startTime: DateTime.now(),
    );
    await repository.createTimeEntry(entry);
    _runningEntryId = entry.id;

    _runningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.invalidateSelf();
    });
  }

  Future<void> stopTimer() async {
    if (_runningEntryId == null) return;

    _runningTimer?.cancel();
    _runningTimer = null;

    final repository = ref.read(timeEntryRepositoryProvider);
    final entries = await repository.getAllTimeEntries();
    final runningEntry = entries.firstWhere(
      (e) => e.id == _runningEntryId,
      orElse: () => throw Exception('Entry not found'),
    );

    final endTime = DateTime.now();
    final duration = endTime.difference(runningEntry.startTime).inMinutes;

    await repository.updateTimeEntry(
      runningEntry.copyWith(
        endTime: endTime,
        durationMinutes: duration,
      ),
    );

    _runningEntryId = null;
  }

  Future<void> createManualEntry({
    required String taskId,
    required DateTime startTime,
    required DateTime endTime,
    String note = '',
  }) async {
    final repository = ref.read(timeEntryRepositoryProvider);
    final duration = endTime.difference(startTime).inMinutes;
    final entry = TimeEntry(
      id: const Uuid().v4(),
      taskId: taskId,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
      note: note,
      manual: true,
    );
    await repository.createTimeEntry(entry);
  }

  Future<void> deleteTimeEntry(String id) async {
    if (_runningEntryId == id) {
      _runningTimer?.cancel();
      _runningEntryId = null;
    }
    final repository = ref.read(timeEntryRepositoryProvider);
    await repository.deleteTimeEntry(id);
  }
}
