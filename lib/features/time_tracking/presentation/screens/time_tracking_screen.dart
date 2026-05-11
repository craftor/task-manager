import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/time_tracking_provider.dart';

class TimeTrackingScreen extends ConsumerStatefulWidget {
  const TimeTrackingScreen({super.key});

  @override
  ConsumerState<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends ConsumerState<TimeTrackingScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesAsync = ref.watch(timeEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Time Tracking'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: () => _showManualEntryDialog(context, ref),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildActiveTimerSection(ref),
          Expanded(
            child: timeEntriesAsync.when(
              data: (entries) => _buildTimeEntryList(context, ref, entries),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => _buildErrorState(error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimerSection(WidgetRef ref) {
    final entriesAsync = ref.watch(timeEntriesProvider);

    return entriesAsync.when(
      data: (entries) {
        final runningEntries = entries.where((e) => e.isRunning).toList();

        if (runningEntries.isEmpty) {
          return _buildStartTimerCard(ref);
        }

        final entry = runningEntries.first;
        final elapsed = DateTime.now().difference(entry.startTime);
        final hours = elapsed.inHours.toString().padLeft(2, '0');
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.secondary.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Timer Running',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$hours:$minutes:$seconds',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

  Widget _buildStartTimerCard(WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Active Timer',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Start a timer to track your time',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
                  onPressed: () => ref.read(timeEntriesProvider.notifier).startTimer('default'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeEntryList(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> entries,
  ) {
    final completedEntries = entries.where((e) => !e.isRunning).toList();

    if (completedEntries.isEmpty) {
      return _buildEmptyState();
    }

    // Group by date
    final groupedEntries = <String, List<dynamic>>{};
    for (final entry in completedEntries) {
      final dateKey = _formatDateKey(entry.startTime);
      groupedEntries.putIfAbsent(dateKey, () => []).add(entry);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final dateKey = groupedEntries.keys.elementAt(index);
        final dayEntries = groupedEntries[dateKey]!;
        final totalMinutes = dayEntries.fold<int>(
          0,
          (sum, e) => sum + ((e.durationMinutes ?? 0) as int),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateKey,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(totalMinutes),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...dayEntries.map((entry) => _TimeEntryCard(
                  entry: entry,
                  onDelete: () =>
                      ref.read(timeEntriesProvider.notifier).deleteTimeEntry(entry.id),
                )),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No Time Entries',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start tracking your time to see entries here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  void _showManualEntryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manual Entry',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Manual time entry coming soon...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeEntryCard extends StatelessWidget {
  final dynamic entry;
  final VoidCallback onDelete;

  const _TimeEntryCard({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final duration = entry.durationMinutes ?? 0;
    final hours = duration ~/ 60;
    final minutes = duration % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeRange(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatTimeRange() {
    final start = _formatTime(entry.startTime);
    final end = entry.endTime != null ? _formatTime(entry.endTime) : 'now';
    return '$start - $end';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}