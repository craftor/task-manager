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
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showAddDialog(),
            tooltip: 'Add special day',
          ),
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
          final yearDays = Map.fromEntries(
            allDays.entries.where((e) => e.key.startsWith(prefix)),
          );
          return _buildGrid(context, yearDays, now);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Error', style: TextStyle(color: AppColors.error))),
      ),
    );
  }

  Color _colorFor(int index) => Color(specialDayColors[index.clamp(0, 5)]);

  Widget _buildGrid(BuildContext context, Map<String, Map<String, String>> specialDays, DateTime now) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final sortedDates = specialDays.keys
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
          if (_year == now.year && sortedDates.length >= 2)
            _buildIntervalsCard(sortedDates),
          if (_year == now.year && sortedDates.length >= 2)
            const SizedBox(height: 16),
          ...List.generate(12, (m) {
            final month = m + 1;
            final daysInMonth = DateTime(_year, month + 1, 0).day;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(monthNames[m],
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: List.generate(31, (d) {
                        final day = d + 1;
                        final exists = day <= daysInMonth;
                        final key = '$_year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                        final data = specialDays[key];
                        final isSpecial = data != null;
                        final isToday = key == todayKey;

                        if (!exists) return const SizedBox(width: 20, height: 18);

                        Color bgColor;
                        Color textColor = AppColors.textMuted;
                        if (isSpecial) {
                          final idx = int.tryParse(data!['color'] ?? '0') ?? 0;
                          final catColor = _colorFor(idx);
                          final date = DateTime(_year, month, day);
                          final isPast = date.isBefore(DateTime(now.year, now.month, now.day + 1));
                          bgColor = isPast ? catColor : catColor.withOpacity(0.5);
                          textColor = Colors.white;
                        } else if (isToday) {
                          bgColor = AppColors.primary.withOpacity(0.3);
                          textColor = AppColors.primary;
                        } else {
                          bgColor = AppColors.border;
                        }

                        return GestureDetector(
                          onTap: isSpecial
                              ? () => _showDayInfo(key, data!, _year, month, day)
                              : null,
                          onLongPress: isSpecial
                              ? () => _showLongPressMenu(key, data!, _year, month, day)
                              : null,
                          child: Container(
                            width: 20, height: 18,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(3),
                              border: isToday && !isSpecial
                                  ? Border.all(color: AppColors.primary, width: 1.5)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w500),
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
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(width: 14, height: 14,
                    decoration: BoxDecoration(color: _colorFor(i), borderRadius: BorderRadius.circular(3))),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildIntervalsCard(List<DateTime> sortedDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? nextSpecial, lastSpecial;
    for (final d in sortedDates) {
      if (d.isAfter(today) || d == today) { nextSpecial = d; break; }
      lastSpecial = d;
    }
    if (nextSpecial == null) nextSpecial = lastSpecial;

    final total = sortedDates.length;
    final daysSince = lastSpecial != null ? today.difference(lastSpecial).inDays : null;
    final daysUntil = nextSpecial != null ? nextSpecial.difference(today).inDays : null;

    double avg = 0;
    if (sortedDates.length >= 2) {
      avg = sortedDates.last.difference(sortedDates.first).inDays / (sortedDates.length - 1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Intervals', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          _Chip(label: 'Total', value: '$total', color: AppColors.primary),
          const SizedBox(width: 12),
          _Chip(label: 'Avg Interval', value: '${avg.toStringAsFixed(1)}d', color: AppColors.secondary),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Chip(label: 'Since last', value: daysSince != null ? '${daysSince}d' : '-', color: AppColors.textMuted),
          const SizedBox(width: 12),
          _Chip(label: 'Until next', value: daysUntil != null ? '${daysUntil}d' : '-', color: AppColors.warning),
        ]),
      ]),
    );
  }

  void _showDayInfo(String key, Map<String, String> data, int year, int month, int day) {
    final idx = int.tryParse(data['color'] ?? '0') ?? 0;
    final desc = data['desc'];
    final date = DateFormat('MMMM d, yyyy').format(DateTime(year, month, day));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _colorFor(idx).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: _colorFor(idx), borderRadius: BorderRadius.circular(3))))),
          const SizedBox(width: 12),
          const Text('Special Day', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(date, style: const TextStyle(color: AppColors.textSecondary)),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
              child: Text(desc, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(specialDaysServiceProvider).removeDay(key);
              ref.invalidate(specialDaysProvider);
              ref.invalidate(specialDaysSortedProvider);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Remove'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showLongPressMenu(String key, Map<String, String> data, int year, int month, int day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Container(width: 14, height: 14,
                    decoration: BoxDecoration(
                        color: _colorFor(int.tryParse(data['color'] ?? '0') ?? 0),
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Text(DateFormat('MMM d, yyyy').format(DateTime(year, month, day)),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.border),
            // Edit
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: const Text('Edit', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(key, data, year, month, day);
              },
            ),
            // Delete
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(key, year, month, day);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showEditDialog(String key, Map<String, String> data, int year, int month, int day) {
    int selectedColor = int.tryParse(data['color'] ?? '0') ?? 0;
    final descController = TextEditingController(text: data['desc'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(width: 320, padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Edit Special Day', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(DateFormat('MMMM d, yyyy').format(DateTime(year, month, day)),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              const Text('Color', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: List.generate(6, (i) {
                final isSel = i == selectedColor;
                return GestureDetector(
                  onTap: () => setD(() => selectedColor = i),
                  child: Container(
                    width: 32, height: 32, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _colorFor(i), shape: BoxShape.circle,
                      border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSel ? [BoxShadow(color: _colorFor(i).withOpacity(0.5), blurRadius: 6)] : null,
                    ),
                    child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              })),
              const SizedBox(height: 20),
              const Text('Description (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  hintText: 'e.g. Mom\'s birthday',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true, fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final desc = descController.text.trim().isEmpty ? null : descController.text.trim();
                    ref.read(specialDaysServiceProvider).setDay(key, selectedColor, desc);
                    ref.invalidate(specialDaysProvider);
                    ref.invalidate(specialDaysSortedProvider);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(String key, int year, int month, int day) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Special Day', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove ${DateFormat('MMMM d, yyyy').format(DateTime(year, month, day))}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(specialDaysServiceProvider).removeDay(key);
              ref.invalidate(specialDaysProvider);
              ref.invalidate(specialDaysSortedProvider);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    DateTime selectedDate = DateTime.now();
    int selectedColor = 0;
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(width: 320, padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Special Day', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              const Text('Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: selectedDate,
                      firstDate: DateTime(2020), lastDate: DateTime(2030),
                      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface)), child: child!));
                  if (d != null) setD(() => selectedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(DateFormat('MMM d, yyyy').format(selectedDate),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Color', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: List.generate(6, (i) {
                final isSel = i == selectedColor;
                return GestureDetector(
                  onTap: () => setD(() => selectedColor = i),
                  child: Container(
                    width: 32, height: 32, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _colorFor(i),
                      shape: BoxShape.circle,
                      border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSel ? [BoxShadow(color: _colorFor(i).withOpacity(0.5), blurRadius: 6)] : null,
                    ),
                    child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              })),
              const SizedBox(height: 20),
              const Text('Description (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  hintText: 'e.g. Mom\'s birthday',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true, fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final key = DateFormat('yyyy-MM-dd').format(selectedDate);
                    final desc = descController.text.trim().isEmpty ? null : descController.text.trim();
                    ref.read(specialDaysServiceProvider).setDay(key, selectedColor, desc);
                    ref.invalidate(specialDaysProvider);
                    ref.invalidate(specialDaysSortedProvider);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
