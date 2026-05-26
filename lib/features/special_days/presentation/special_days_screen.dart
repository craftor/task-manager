import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/datasources/remote/supabase_datasource.dart';
import '../../special_days/special_days_provider.dart';
import '../../special_days/special_days_service.dart';
import '../../sync/data/sync_manager.dart';
import '../../sync/presentation/providers/sync_status_provider.dart';

class SpecialDaysScreen extends ConsumerStatefulWidget {
  const SpecialDaysScreen({super.key});

  @override
  ConsumerState<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends ConsumerState<SpecialDaysScreen> {
  late int _year;
  bool _isUnlocked = false;
  bool _showCalendar = false; // true = 7-day row calendar, false = 28-31 cells per month row
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToCurrentYear = false;

  SupabaseDatasource? get _remote => ref.read(supabaseDatasourceProvider);

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    Future.microtask(() {
      ref.invalidate(specialDaysProvider);
      ref.invalidate(specialDaysSortedProvider);
    });
  }

  void _scrollToCurrentYear() {
    if (_scrollController.hasClients) {
      final startYear = DateTime.now().year - 5;
      final targetOffset = (_year - startYear) * 360.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _isCurrentYear => _year == DateTime.now().year;
  bool get _isLocked => !_isCurrentYear && !_isUnlocked;

  @override
  Widget build(BuildContext context) {
    // Invalidate on each sync success (SyncManager writes to SharedPreferences)
    ref.listen(syncStatusProvider, (prev, next) {
      final now = next.valueOrNull;
      if (now != null && now.status == SyncStatus.success) {
        ref.invalidate(specialDaysProvider);
        ref.invalidate(specialDaysSortedProvider);
      }
    });
    final specialDaysAsync = ref.watch(specialDaysProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Special Days'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_isLocked)
            IconButton(
              icon: const Icon(Icons.lock_outline, color: AppColors.warning),
              onPressed: () => setState(() => _isUnlocked = true),
              tooltip: 'Unlock to edit past year',
            ),
          if (!_isLocked && !_isCurrentYear)
            IconButton(
              icon: const Icon(Icons.lock_open, color: AppColors.primary),
              onPressed: () => setState(() => _isUnlocked = false),
              tooltip: 'Lock past year',
            ),
          if (!_isLocked && _isCurrentYear)
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: () => _showAddDialog(),
              tooltip: 'Add special day',
            ),
          if (_showCalendar) ...[
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => setState(() {
              _year--;
              _isUnlocked = false;
            }),
          ),
          Text(
            '$_year',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => setState(() {
              _year++;
              _isUnlocked = false;
            }),
          ),
          const SizedBox(width: 4),
          ],
          // View mode toggle
          PopupMenuButton<bool>(
            icon: Icon(_showCalendar ? Icons.grid_view : Icons.view_agenda, color: AppColors.textPrimary, size: 20),
            tooltip: 'Toggle view',
            onSelected: (v) => setState(() => _showCalendar = v),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: false, child: Row(children: [
                Icon(_showCalendar ? null : Icons.check, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                const Text('Month Row'),
              ])),
              PopupMenuItem(value: true, child: Row(children: [
                Icon(_showCalendar ? Icons.check : null, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                const Text('Calendar'),
              ])),
            ],
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
          return _showCalendar ? _buildCalendarGrid(context, yearDays, now) : _buildMonthRowGrid(context, allDays, now, scrollController: _scrollController, firstBuild: !_scrolledToCurrentYear && !_showCalendar, onScrolled: () { _scrolledToCurrentYear = true; });
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Error', style: TextStyle(color: AppColors.error))),
      ),
    );
  }

  Color _colorFor(int index) => Color(specialDayColors[index.clamp(0, 5)]);

  // ─── Calendar Grid (7 days per row) ───
  Widget _buildCalendarGrid(BuildContext context, Map<String, Map<String, String>> specialDays, DateTime now) {
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final months = List.generate(12, (m) => _buildCalendarMonth(context, m, specialDays, todayKey, now));

        if (isNarrow) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: months,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: months.map((m) => SizedBox(width: 220, child: m)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCalendarMonth(BuildContext context, int m, Map<String, Map<String, String>> specialDays, String todayKey, DateTime now) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    final month = m + 1;
    final daysInMonth = DateTime(_year, month + 1, 0).day;
    final firstDay = DateTime(_year, month, 1).weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(monthNames[m], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(children: dayLabels.map((l) => SizedBox(width: 28, height: 18, child: Center(child: Text(l, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 2),
        ...List.generate(((daysInMonth + firstDay + 6) ~/ 7), (weekRow) {
          return Row(children: List.generate(7, (dayOfWeek) {
            final dayIndex = weekRow * 7 + dayOfWeek - firstDay + 1;
            final day = dayIndex;
            if (day < 1 || day > daysInMonth) return const SizedBox(width: 28, height: 22);
            final key = '$_year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final data = specialDays[key];
            final isSpecial = data != null;
            final isToday = key == todayKey;
            Color bgColor; Color textColor = AppColors.textMuted;
            if (isSpecial) {
              final idx = int.tryParse(data['color'] ?? '0') ?? 0;
              final catColor = _colorFor(idx);
              final date = DateTime(_year, month, day);
              final isPast = date.isBefore(DateTime(now.year, now.month, now.day + 1));
              bgColor = isPast ? catColor : catColor.withValues(alpha: 0.5);
              textColor = Colors.white;
            } else if (isToday) {
              bgColor = AppColors.primary.withValues(alpha: 0.3);
              textColor = AppColors.primary;
            } else {
              bgColor = AppColors.border;
            }
            return GestureDetector(
              onTap: () { if (_isLocked) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock to edit past years'), duration: Duration(seconds: 1))); return; } if (isSpecial) { _showDayInfo(key, data, _year, month, day); } else { _showAddDialogForDate(DateTime(_year, month, day)); } },
              onLongPress: _isLocked ? null : (isSpecial ? () => _showLongPressMenu(key, data, _year, month, day) : null),
              child: Container(width: 28, height: 22, decoration: BoxDecoration(color: _isLocked && isSpecial ? bgColor.withValues(alpha: 0.4) : bgColor, borderRadius: BorderRadius.circular(4), border: isToday && !isSpecial ? Border.all(color: AppColors.primary, width: 1.5) : (isSpecial && _isLocked ? Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 1) : null)), alignment: Alignment.center, child: Text('$day', style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w500))),
            );
          }));
        }),
      ],
    );
  }

  // ─── Month Row Grid (28-31 cells per month row) ───
  Widget _buildMonthRowGrid(BuildContext context, Map<String, Map<String, String>> specialDays, DateTime now, {ScrollController? scrollController, bool firstBuild = false, VoidCallback? onScrolled}) {
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // Scroll to current year on first build
    if (firstBuild && scrollController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          final targetOffset = (now.year - 2020) * 360.0;
          scrollController.animateTo(
            targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          onScrolled?.call();
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        // Show 2020-2030 for continuous scrolling
        final allYearMonths = <Widget>[];
        final currentYear = DateTime.now().year;
        for (int y = currentYear - 5; y <= currentYear + 5; y++) {
          // Year label before January
          allYearMonths.add(Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SizedBox(
              width: 40,
              child: Text('$y', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ));
          for (int m = 1; m <= 12; m++) {
            final isLastMonth = m == 12;
            allYearMonths.add(_buildMonthRow(y, m, specialDays, todayKey, now, isLastMonth: isLastMonth));
            if (m < 12) {
              allYearMonths.add(const SizedBox(height: 4));
            }
          }
          if (y < 2030) {
            allYearMonths.add(const SizedBox(height: 8));
          }
        }

        if (isNarrow) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: allYearMonths,
            ),
          );
        }

        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: allYearMonths,
          ),
        );
      },
    );
  }

  Widget _buildMonthRow(int year, int month, Map<String, Map<String, String>> specialDays, String todayKey, DateTime now, {bool isLastMonth = false}) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final daysInMonth = DateTime(year, month + 1, 0).day;
    const cellSize = 22.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastMonth ? 16 : 4,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(monthNames[month - 1], style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(daysInMonth, (d) {
                    final day = d + 1;
                    final key = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    final data = specialDays[key];
                    final isSpecial = data != null;
                    final isToday = key == todayKey;

                    Color bgColor; Color textColor = AppColors.textMuted;
                    if (isSpecial) {
                      final idx = int.tryParse(data['color'] ?? '0') ?? 0;
                      final catColor = _colorFor(idx);
                      final date = DateTime(year, month, day);
                      final isPast = date.isBefore(DateTime(now.year, now.month, now.day + 1));
                      bgColor = isPast ? catColor : catColor.withValues(alpha: 0.5);
                      textColor = Colors.white;
                    } else if (isToday) {
                      bgColor = AppColors.primary.withValues(alpha: 0.3);
                      textColor = AppColors.primary;
                    } else {
                      bgColor = AppColors.border;
                    }

                    return GestureDetector(
                      onTap: () { if (_isLocked) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock to edit past years'), duration: Duration(seconds: 1))); return; } if (isSpecial) { _showDayInfo(key, data, year, month, day); } else { _showAddDialogForDate(DateTime(year, month, day)); } },
                      onLongPress: _isLocked ? null : (isSpecial ? () => _showLongPressMenu(key, data, year, month, day) : null),
                      child: Container(
                        width: cellSize, height: cellSize,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(color: _isLocked && isSpecial ? bgColor.withValues(alpha: 0.4) : bgColor, borderRadius: BorderRadius.circular(3), border: isToday && !isSpecial ? Border.all(color: AppColors.primary, width: 1.5) : (isSpecial && _isLocked ? Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 1) : null)),
                        alignment: Alignment.center,
                        child: Text('$day', style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w500)),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
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
              decoration: BoxDecoration(color: _colorFor(idx).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
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
              if (_remote != null) ref.read(specialDaysServiceProvider).removeDay(_remote!, key);
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
                      boxShadow: isSel ? [BoxShadow(color: _colorFor(i).withValues(alpha: 0.5), blurRadius: 6)] : null,
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
                    if (_remote != null) ref.read(specialDaysServiceProvider).setDay(_remote!, key, selectedColor, desc);
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
              if (_remote != null) ref.read(specialDaysServiceProvider).removeDay(_remote!, key);
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

  void _showAddDialogForDate(DateTime date) {
    _showAddDialog(initialDate: date);
  }

  void _showAddDialog({DateTime? initialDate}) {
    DateTime selectedDate = initialDate ?? DateTime.now();
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
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)), lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
                      boxShadow: isSel ? [BoxShadow(color: _colorFor(i).withValues(alpha: 0.5), blurRadius: 6)] : null,
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
                    if (_remote != null) ref.read(specialDaysServiceProvider).setDay(_remote!, key, selectedColor, desc);
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
