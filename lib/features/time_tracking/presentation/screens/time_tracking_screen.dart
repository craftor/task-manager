import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/time_tracking_provider.dart';

class TimeTrackingScreen extends ConsumerWidget {
  const TimeTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeEntriesAsync = ref.watch(timeEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Time Tracking'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showManualEntryDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _ActiveTimerCard(ref: ref),
          Expanded(
            child: timeEntriesAsync.when(
              data: (entries) => _buildTimeEntryList(context, ref, entries),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ActiveTimerCard({required WidgetRef ref}) {
    final entriesAsync = ref.watch(timeEntriesProvider);

    return entriesAsync.when(
      data: (entries) {
        final runningEntry = entries.where((e) => e.isRunning).toList();
        if (runningEntry.isEmpty) return const SizedBox.shrink();

        final entry = runningEntry.first;
        final elapsed = DateTime.now().difference(entry.startTime);
        final hours = elapsed.inHours.toString().padLeft(2, '0');
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, color: AppColors.primary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Running',
                      style: TextStyle(color: AppColors.primary, fontSize: 14),
                    ),
                    Text(
                      '$hours:$minutes:$seconds',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    ref.read(timeEntriesProvider.notifier).stopTimer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTimeEntryList(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> entries,
  ) {
    final completedEntries = entries.where((e) => !e.isRunning).toList();

    if (completedEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 64, color: AppColors.border),
            SizedBox(height: 16),
            Text(
              'No time entries yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedEntries.length,
      itemBuilder: (context, index) {
        final entry = completedEntries[index];
        final duration = entry.durationMinutes ?? 0;
        final hours = duration ~/ 60;
        final minutes = duration % 60;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_arrow, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task: ${entry.taskId}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${entry.startTime.toString().split('.')[0]} - ${entry.endTime?.toString().split('.')[0] ?? 'now'}',
                        style: const TextStyle(
                          color: AppColors.border,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${hours}h ${minutes}m',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () =>
                      ref.read(timeEntriesProvider.notifier).deleteTimeEntry(entry.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualEntryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Manual Time Entry'),
        content: const Text(
          'Select a task to track time for it manually.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Entry'),
          ),
        ],
      ),
    );
  }
}
