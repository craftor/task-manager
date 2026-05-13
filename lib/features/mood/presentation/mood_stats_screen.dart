import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../sync/data/sync_manager.dart';
import '../../sync/presentation/providers/sync_status_provider.dart' show syncStatusProvider, supabaseDatasourceProvider;
import '../../../../data/datasources/remote/supabase_datasource.dart';
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
  DateTime? _lastSyncTime;

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) { _month = 12; _year--; }
    });
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) { _month = 1; _year++; }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Auto-refresh after sync completes
    final syncState = ref.watch(syncStatusProvider);
    final lastSync = syncState.valueOrNull?.lastSyncTime;
    if (lastSync != null && lastSync != _lastSyncTime) {
      _lastSyncTime = lastSync;
      // Schedule invalidation after build to avoid modifying during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(allMoodsProvider);
        ref.invalidate(weeklyMoodDistributionProvider);
      });
    }

    final moodsAsync = ref.watch(allMoodsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mood Stats'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          LayoutBuilder(builder: (c, cs) {
            final compact = cs.maxWidth < AppConstants.compactBreakpoint;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              // Month mode: prev/next month
              if (!_yearlyMode) ...[
                IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 20), onPressed: _prevMonth),
                Text('$_year-${_month.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary, size: 20), onPressed: _nextMonth),
              ],
              // Year mode: prev/next year
              if (_yearlyMode) ...[
                IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 20), onPressed: () => setState(() => _year--)),
                Text('$_year', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary, size: 20), onPressed: () => setState(() => _year++)),
              ],
              const SizedBox(width: 8),
              // Mode toggle
              if (compact)
                Container(
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.all(2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => setState(() => _yearlyMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _yearlyMode ? Colors.transparent : AppColors.primary, borderRadius: BorderRadius.circular(4)),
                        child: Text('M', style: TextStyle(color: _yearlyMode ? AppColors.textMuted : Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    GestureDetector(onTap: () => setState(() => _yearlyMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _yearlyMode ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                        child: Text('Y', style: TextStyle(color: _yearlyMode ? Colors.white : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                )
              else
                SegmentedButton<bool>(
                  selected: {_yearlyMode},
                  onSelectionChanged: (v) => setState(() => _yearlyMode = v.first),
                  style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.primary.withOpacity(0.2) : Colors.transparent)),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Month', style: TextStyle(fontSize: 13))),
                    ButtonSegment(value: true, label: Text('Year', style: TextStyle(fontSize: 13))),
                  ],
                ),
              const SizedBox(width: 4),
            ]);
          }),
        ],
      ),
      body: moodsAsync.when(
        data: (moods) => _yearlyMode ? _buildYearlyStats(moods, now) : _buildMonthlyStats(moods, now),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load', style: TextStyle(color: AppColors.error))),
      ),
    );
  }

  // ─── Monthly Stats ───
  Widget _buildMonthlyStats(Map<String, List<String>> moods, DateTime now) {
    final prefix = '$_year-${_month.toString().padLeft(2, '0')}-';
    final monthMoods = moods.entries.where((e) => e.key.startsWith(prefix)).toList();

    final distribution = <String, int>{};
    for (final e in monthMoods) {
      for (final emoji in e.value) {
        distribution[emoji] = (distribution[emoji] ?? 0) + 1;
      }
    }
    final entries = distribution.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstWeekday = DateTime(_year, _month, 1).weekday;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (entries.isNotEmpty) ...[
          _SummaryRow(distribution: entries, total: total),
          const SizedBox(height: 24),
          const Text('Distribution', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              Text(e.key, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 24, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.primary)))),
              const SizedBox(width: 10),
              SizedBox(width: 50, child: Text('${e.value}d  ${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            ]));
          }),
          const SizedBox(height: 24),
        ],
        const Text('Calendar', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildMoodCalendarGrid(year: _year, month: _month, daysInMonth: daysInMonth, firstWeekday: firstWeekday, moods: moods, prefix: prefix),
      ]),
    );
  }

  // ─── Yearly Stats ───
  Widget _buildYearlyStats(Map<String, List<String>> moods, DateTime now) {
    final yearPrefix = '$_year-';
    final allYearMoods = moods.entries.where((e) => e.key.startsWith(yearPrefix)).toList();

    final monthly = <int, Map<String, int>>{};
    for (final e in allYearMoods) {
      final m = int.parse(e.key.substring(5, 7));
      monthly.putIfAbsent(m, () => {});
      for (final emoji in e.value) {
        monthly[m]![emoji] = (monthly[m]![emoji] ?? 0) + 1;
      }
    }

    final overallDist = <String, int>{};
    for (final e in allYearMoods) {
      for (final emoji in e.value) {
        overallDist[emoji] = (overallDist[emoji] ?? 0) + 1;
      }
    }
    final overallEntries = overallDist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = allYearMoods.fold<int>(0, (s, e) => s + e.value.length);

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (total > 0) _SummaryRow(distribution: overallEntries, total: total),
      if (total > 0) ...[
        const SizedBox(height: 24),
        const Text('Year Distribution', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...overallEntries.map((e) {
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Text(e.key, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 24, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.primary)))),
            const SizedBox(width: 10),
            SizedBox(width: 50, child: Text('${e.value}d  ${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ]));
        }),
        const SizedBox(height: 24),
      ],
      const Text('Monthly Breakdown', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ...List.generate(12, (i) {
        final m = i + 1;
        final dist = monthly[m];
        final count = dist?.values.fold<int>(0, (a, b) => a + b) ?? 0;
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          SizedBox(width: 36, child: Text(monthNames[m], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Container(height: 22, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)), clipBehavior: Clip.hardEdge,
            child: Row(children: dist?.entries.map((e) {
              final pct = count > 0 ? e.value / count : 0.0;
              return Expanded(flex: (pct * 100).round().clamp(1, 100), child: Container(color: _moodColor(e.key).withOpacity(0.7)));
            }).toList() ?? []))),
          const SizedBox(width: 8),
          SizedBox(width: 150, child: Text(dist?.entries.map((e) => '${e.key}×${e.value}').join('  ') ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis)),
        ]));
      }),
    ]));
  }

  // ─── Calendar Grid ───
  Widget _buildMoodCalendarGrid({required int year, required int month, required int daysInMonth, required int firstWeekday, required Map<String, List<String>> moods, required String prefix}) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(children: [
      Row(children: weekdays.map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))))).toList()),
      const SizedBox(height: 4),
      ..._buildCalendarRows(year, month, daysInMonth, firstWeekday, moods, prefix),
    ]);
  }

  List<Widget> _buildCalendarRows(int year, int month, int days, int firstWeekday, Map<String, List<String>> moods, String prefix) {
    final rows = <Widget>[];
    var day = 1;
    for (var week = 0; week < 6 && day <= days; week++) {
      final cells = <Widget>[];
      for (var wd = 1; wd <= 7; wd++) {
        if ((week == 0 && wd < firstWeekday) || day > days) {
          cells.add(const Expanded(child: SizedBox(height: 44)));
        } else {
          final key = '$prefix${day.toString().padLeft(2, '0')}';
          final emojis = moods[key] ?? [];
          final d = day;
          cells.add(Expanded(child: GestureDetector(
            onTap: () => _showMoodPicker(key, emojis),
            child: Container(
              height: 44, margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: emojis.isNotEmpty ? _moodColor(emojis.first).withOpacity(0.12) : AppColors.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (emojis.isEmpty)
                  Text('$d', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))
                else
                  Text(emojis.join(''), style: const TextStyle(fontSize: 11)),
              ]),
            ),
          )));
          day++;
        }
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  void _showMoodPicker(String dateKey, List<String> current) {
    final selected = Set<String>.from(current);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(width: 320, padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(DateFormat('MMM d, yyyy').format(DateTime.parse(dateKey)),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Tap to toggle · Max 3 moods', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: moodEmojis.map((e) {
              final isSel = selected.contains(e);
              return GestureDetector(
                onTap: () {
                  setSt(() {
                    if (isSel) {
                      selected.remove(e);
                    } else if (selected.length < 3) {
                      selected.add(e);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSel ? _moodColor(e).withOpacity(0.2) : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSel ? _moodColor(e) : AppColors.border, width: isSel ? 2 : 1),
                  ),
                  child: Column(children: [
                    Text(e, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 2),
                    Text(moodLabels[e] ?? '', style: TextStyle(color: isSel ? _moodColor(e) : AppColors.textMuted, fontSize: 10)),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (current.isNotEmpty)
                TextButton(onPressed: () {
                  final remote = ref.read(supabaseDatasourceProvider);
                  if (remote != null) ref.read(moodServiceProvider).removeMoods(remote, dateKey);
                  ref.invalidate(allMoodsProvider);
                  ref.invalidate(weeklyMoodDistributionProvider);
                  Navigator.pop(ctx);
                }, child: const Text('Clear', style: TextStyle(color: AppColors.error))),
              const SizedBox(width: 8),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () {
                final remote = ref.read(supabaseDatasourceProvider);
                if (remote != null) ref.read(moodServiceProvider).setMoods(remote, dateKey, selected.toList());
                ref.invalidate(allMoodsProvider);
                ref.invalidate(weeklyMoodDistributionProvider);
                Navigator.pop(ctx);
              }, child: const Text('Save')),
            ]),
          ]),
        ),
      )),
    );
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
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Text(top, style: const TextStyle(fontSize: 40)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${moodLabels[top] ?? top} dominates', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$total entries this period', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])),
      ]));
  }
}
