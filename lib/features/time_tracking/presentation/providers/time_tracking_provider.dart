import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/database_provider.dart';
import '../../../../domain/entities/time_entry.dart';
import '../../data/time_entry_repository_impl.dart';
import '../../domain/time_entry_repository.dart';

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  return TimeEntryRepositoryImpl(ref.watch(databaseProvider));
});

final timeEntriesProvider =
    StreamNotifierProvider<TimeEntriesNotifier, List<TimeEntry>>(
  TimeEntriesNotifier.new,
);

/// Tracks the id of the entry currently being timed (if any), so screens
/// can render the running timer without holding their own periodic
/// Timer. This replaces the per-screen `Timer.periodic` that caused
/// double-tick rebuilds and the broken `ref.invalidateSelf()` loop in
/// the previous notifier (each tick rebuilt `build()`, leaked the old
/// `_runningTimer`, and accumulated timers across seconds).
final runningEntryIdProvider = StateProvider<String?>((ref) => null);

/// Live "now" timestamp, ticking once per second while a timer is
/// running. The screen watches this to render the elapsed duration.
final stopwatchProvider = StreamProvider<DateTime>((ref) {
  final id = ref.watch(runningEntryIdProvider);
  if (id == null) return const Stream.empty();
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

class TimeEntriesNotifier extends StreamNotifier<List<TimeEntry>> {
  @override
  Stream<List<TimeEntry>> build() {
    return ref.watch(timeEntryRepositoryProvider).watchAllTimeEntries();
  }

  Future<void> startTimer(String taskId) async {
    // If a previous timer is still running, stop it first so we don't
    // leave an orphan "running" entry.
    final previousId = ref.read(runningEntryIdProvider);
    if (previousId != null) {
      await stopTimer();
    }

    final repository = ref.read(timeEntryRepositoryProvider);
    final entry = TimeEntry(
      id: const Uuid().v4(),
      taskId: taskId,
      startTime: DateTime.now(),
    );
    await repository.createTimeEntry(entry);
    ref.read(runningEntryIdProvider.notifier).state = entry.id;
  }

  Future<void> stopTimer() async {
    final id = ref.read(runningEntryIdProvider);
    if (id == null) return;
    ref.read(runningEntryIdProvider.notifier).state = null;

    final repository = ref.read(timeEntryRepositoryProvider);
    final runningEntry = await repository.getTimeEntryById(id);
    if (runningEntry == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(runningEntry.startTime).inMinutes;

    await repository.updateTimeEntry(
      runningEntry.copyWith(
        endTime: endTime,
        durationMinutes: duration,
      ),
    );
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
    if (ref.read(runningEntryIdProvider) == id) {
      ref.read(runningEntryIdProvider.notifier).state = null;
    }
    final repository = ref.read(timeEntryRepositoryProvider);
    await repository.deleteTimeEntry(id);
  }
}