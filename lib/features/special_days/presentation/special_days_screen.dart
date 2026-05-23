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

    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          bgColor = isPast ? catColor : catColor.withValues(alpha: 0.5);
                          textColor = Colors.white;
                        } else if (isToday) {
                          bgColor = AppColors.primary.withValues(alpha: 0.3);
                          textColor = AppColors.primary;
                        } else {
                          bgColor = AppColors.border;
                        }

                        return GestureDetector(
                          onTap: () {
                            if (_isLocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Unlock to edit past years'), duration: Duration(seconds: 1)),
                              );
                              return;
                            }
                            if (isSpecial) {
                              _showDayInfo(key, data!, _year, month, day);
                            } else {
                              _showAddDialogForDate(DateTime(_year, month, day));
                            }
                          },
                          onLongPress: _isLocked ? null : (isSpecial
                              ? () => _showLongPressMenu(key, data!, _year, month, day)
                              : null),
                          child: Container(
                            width: 20, height: 18,
                            decoration: BoxDecoration(
                              color: _isLocked && isSpecial ? bgColor.withValues(alpha: 0.4) : bgColor,
                              borderRadius: BorderRadius.circular(3),
                              border: isToday && !isSpecial
                                  ? Border.all(color: AppColors.primary, width: 1.5)
                                  : (isSpecial && _isLocked ? Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 1) : null),
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
          const SizedBox(height: 12),
          // Color legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final labels = ['Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: _colorFor(i), borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 4),
                    Text(labels[i], style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ]),
                );
              }),
            ),
          ),
        ],
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
