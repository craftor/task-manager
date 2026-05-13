import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../mood/mood_provider.dart';
import '../../mood/mood_service.dart';

class MoodStatsScreen extends ConsumerStatefulWidget {
  const MoodStatsScreen({super.key});

  @override
  ConsumerState<MoodStatsScreen> createState() => _MoodStatsScreenState();
}

class _MoodStatsScreenState extends ConsumerState<MoodStatsScreen> {
  bool _yearlyMode = false;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final moodsAsync = ref.watch(allMoodsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mood Stats'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // Year navigation
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => setState(() => _year--),
          ),
          Text(
            _yearlyMode ? '$_year' : '${_year}-${_month.toString().padLeft(2, '0')}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => setState(() => _year++),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool>(
            selected: {_yearlyMode},
            onSelectionChanged: (v) => setState(() => _yearlyMode = v.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary.withOpacity(0.2);
                }
                return Colors.transparent;
              }),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('Month')),
              ButtonSegment(value: true, label: Text('Year')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: moodsAsync.when(
        data: (moods) => _buildStats(moods, now),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildStats(Map<String, String> moods, DateTime now) {
    if (_yearlyMode) {
      return _buildYearlyStats(moods, now);
    } else {
      return _buildMonthlyStats(moods, now);
    }
  }

  // ─── Monthly Stats ───
  Widget _buildMonthlyStats(Map<String, String> moods, DateTime now) {
    final yearMonth = '$_year-${_month.toString().padLeft(2, '0')}';
    final prefix = '$yearMonth-';
    final monthMoods = moods.entries
        .where((e) => e.key.startsWith(prefix))
        .toList();

    if (monthMoods.isEmpty) {
      // Still show calendar grid, just with empty distribution
      final daysInMonth = DateTime(_year, _month + 1, 0).day;
      final firstWeekday = DateTime(_year, _month, 1).weekday;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const SizedBox(height: 40),
          const Text('😶 No moods this month',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          // Calendar grid with no moods
          _buildMoodCalendarGrid(
            year: _year, month: _month,
            daysInMonth: daysInMonth, firstWeekday: firstWeekday,
            moods: {}, prefix: prefix,
          ),
        ]),
      );
    }

    final distribution = <String, int>{};
    for (final e in monthMoods) {
      distribution[e.value] = (distribution[e.value] ?? 0) + 1;
    }
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = monthMoods.length;

    // Build calendar grid for the month
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstWeekday = DateTime(_year, _month, 1).weekday;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary bar
          _SummaryRow(
            distribution: entries,
            total: total,
          ),
          const SizedBox(height: 24),
          // Distribution bars
          const Text('Distribution',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text(e.key, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 24,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${e.value}d  ${(pct * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 24),
          // Calendar grid
          const Text('Calendar',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildMoodCalendarGrid(
            year: _year, month: _month,
            daysInMonth: daysInMonth, firstWeekday: firstWeekday,
            moods: moods, prefix: prefix,
          ),
        ],
      ),
    );
  }

  // ─── Yearly Stats ───
  Widget _buildYearlyStats(Map<String, String> moods, DateTime now) {
    final yearPrefix = '$_year-';
    final allYearMoods = moods.entries
        .where((e) => e.key.startsWith(yearPrefix))
        .toList();

    final hasData = allYearMoods.isNotEmpty;

    // Per-month distribution (always build for all 12 months)
    final monthly = <int, Map<String, int>>{};
    for (final e in allYearMoods) {
      final month = int.parse(e.key.substring(5, 7));
      monthly.putIfAbsent(month, () => {});
      monthly[month]![e.value] = (monthly[month]![e.value] ?? 0) + 1;
    }

    // Overall distribution
    final overallDist = <String, int>{};
    for (final e in allYearMoods) {
      overallDist[e.value] = (overallDist[e.value] ?? 0) + 1;
    }
    final overallEntries = overallDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = allYearMoods.length;

    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall summary
          if (hasData) _SummaryRow(distribution: overallEntries, total: total),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('😶 No moods this year',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
            ),
          const SizedBox(height: 24),
          // Full-year distribution bars
          if (hasData) ...[
            const Text('Year Distribution',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...overallEntries.map((e) {
              final pct = total > 0 ? e.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text(e.key, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 24,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${e.value}d  ${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 24),
          ],
          // Monthly breakdown
          const Text('Monthly Breakdown',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...List.generate(12, (i) {
            final m = i + 1;
            final dist = monthly[m];
            final count = dist?.values.fold<int>(0, (a, b) => a + b) ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 36,
                  child: Text(monthNames[m],
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                Expanded(
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Row(
                      children: dist?.entries
                              .map((e) {
                                final pct = count > 0 ? e.value / count : 0.0;
                                return Expanded(
                                  flex: (pct * 100).round().clamp(1, 100),
                                  child: Container(
                                    color: _moodColor(e.key).withOpacity(0.7),
                                  ),
                                );
                              })
                              .toList() ??
                          [],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: Text(
                    dist?.entries
                            .map((e) => '${e.key}×${e.value}')
                            .join('  ') ??
                        '',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMoodCalendarGrid({
    required int year, required int month,
    required int daysInMonth, required int firstWeekday,
    required Map<String, String> moods, required String prefix,
  }) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(children: [
      Row(
        children: weekdays.map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
        )).toList(),
      ),
      const SizedBox(height: 4),
      ..._buildCalendarRows(year, month, daysInMonth, firstWeekday, moods, prefix),
    ]);
  }

  List<Widget> _buildCalendarRows(int year, int month, int days, int firstWeekday,
      Map<String, String> moods, String prefix) {
    final rows = <Widget>[];
    var day = 1;
    for (var week = 0; week < 6 && day <= days; week++) {
      final cells = <Widget>[];
      for (var wd = 1; wd <= 7; wd++) {
        if ((week == 0 && wd < firstWeekday) || day > days) {
          cells.add(const Expanded(child: SizedBox(height: 36)));
        } else {
          final key = '$prefix${day.toString().padLeft(2, '0')}';
          final emoji = moods[key];
          cells.add(Expanded(
            child: Container(
              height: 36,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: emoji != null
                    ? _moodColor(emoji).withOpacity(0.15)
                    : AppColors.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  emoji ?? '$day',
                  style: TextStyle(
                    fontSize: emoji != null ? 14 : 11,
                    color: emoji != null ? null : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ));
          day++;
        }
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  Color _moodColor(String emoji) {
    switch (emoji) {
      case '😊': return const Color(0xFF4CAF50);
      case '😢': return const Color(0xFF2196F3);
      case '😡': return const Color(0xFFF44336);
      case '😴': return const Color(0xFF9E9E9E);
      case '😐': return const Color(0xFF607D8B);
      case '🎉': return const Color(0xFFFF9800);
      case '😰': return const Color(0xFF9C27B0);
      case '❤️': return const Color(0xFFE91E63);
      default: return AppColors.primary;
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final List<MapEntry<String, int>> distribution;
  final int total;

  const _SummaryRow({required this.distribution, required this.total});

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    final top = distribution.first.key;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Text(top, style: const TextStyle(fontSize: 40)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${moodLabels[top] ?? top} dominates',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '$total entries this ${distribution.length > 1 ? "period" : "period"}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
