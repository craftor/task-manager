import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../special_days/special_days_provider.dart';
import '../../special_days/special_days_service.dart';

class SpecialDaysScreen extends ConsumerStatefulWidget {
  const SpecialDaysScreen({super.key});

  @override
  ConsumerState<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends ConsumerState<SpecialDaysScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final specialDaysAsync = ref.watch(specialDaysProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Special Days'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // Year navigation
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => setState(() => _year--),
          ),
          Text(
            '$_year',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => setState(() => _year++),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: specialDaysAsync.when(
        data: (allDays) {
          final prefix = '$_year-';
          final yearDays = allDays.where((d) => d.startsWith(prefix)).toSet();
          return _buildGrid(context, yearDays, now);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Error', style: TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, Set<String> specialDays, DateTime now) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final sortedDates = specialDays
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList()
      ..sort();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intervals summary (only for current year)
          if (_year == now.year && sortedDates.length >= 2)
            _buildIntervalsCard(sortedDates),
          if (_year == now.year && sortedDates.length >= 2)
            const SizedBox(height: 16),
          // 12-month grid
          ...List.generate(12, (m) {
            final month = m + 1;
            final daysInMonth = DateTime(_year, month + 1, 0).day;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      monthNames[m],
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: List.generate(31, (d) {
                        final day = d + 1;
                        final exists = day <= daysInMonth;
                        final key = '$_year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                        final isSpecial = specialDays.contains(key);
                        final isToday = key == todayKey;

                        if (!exists) {
                          return const SizedBox(width: 14, height: 14);
                        }

                        Color bgColor;
                        if (isSpecial) {
                          final date = DateTime(_year, month, day);
                          final isPast = date.isBefore(DateTime(now.year, now.month, now.day + 1));
                          bgColor = isPast ? AppColors.primary : AppColors.warning;
                        } else if (isToday) {
                          bgColor = AppColors.primary.withOpacity(0.3);
                        } else {
                          bgColor = AppColors.border;
                        }

                        return GestureDetector(
                          onTap: () async {
                            await ref.read(specialDaysServiceProvider).toggleDay(key);
                            ref.invalidate(specialDaysProvider);
                          },
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(3),
                              border: isToday && !isSpecial
                                  ? Border.all(color: AppColors.primary, width: 1.5)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          // Legend
          Row(children: [
            Container(width: 14, height: 14,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            const Text('Past special', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 16),
            Container(width: 14, height: 14,
                decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            const Text('Upcoming special', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(width: 16),
            Container(width: 14, height: 14,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            const Text('Normal', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _buildIntervalsCard(List<DateTime> sortedDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? nextSpecial;
    DateTime? lastSpecial;
    for (final d in sortedDates) {
      if (d.isAfter(today) || d == today) {
        nextSpecial = d;
        break;
      }
      lastSpecial = d;
    }
    if (nextSpecial == null) nextSpecial = lastSpecial;

    final totalCount = sortedDates.length;
    final daysSince = lastSpecial != null ? today.difference(lastSpecial).inDays : null;
    final daysUntil = nextSpecial != null ? nextSpecial.difference(today).inDays : null;

    double avgInterval = 0;
    if (sortedDates.length >= 2) {
      final first = sortedDates.first;
      final last = sortedDates.last;
      avgInterval = last.difference(first).inDays / (sortedDates.length - 1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Intervals',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _IntervalChip(label: 'Total', value: '$totalCount', color: AppColors.primary),
            const SizedBox(width: 12),
            _IntervalChip(label: 'Avg Interval', value: '${avgInterval.toStringAsFixed(1)}d', color: AppColors.secondary),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _IntervalChip(
              label: 'Since last',
              value: daysSince != null ? '${daysSince}d' : '-',
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            _IntervalChip(
              label: 'Until next',
              value: daysUntil != null ? '${daysUntil}d' : '-',
              color: AppColors.warning,
            ),
          ]),
        ],
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _IntervalChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
