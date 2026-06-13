import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../sync/data/sync_manager.dart' show SyncStatus;
import '../../sync/presentation/providers/sync_status_provider.dart';
import '../domain/journal_entry.dart';
import 'providers/journal_provider.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _controller = TextEditingController();
  final _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _hasUnsaved = false;
  String? _editingEntryId;

  RemoteDatasource? get _remote => ref.read(remoteDatasourceProvider);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    if (!_hasUnsaved) setState(() => _hasUnsaved = true);
  }

  Future<void> _saveToday() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_remote != null && _editingEntryId != null) {
      await ref.read(journalActionsProvider).delete(_todayKey, _editingEntryId!);
      _editingEntryId = null;
    }
    if (_remote != null) await ref.read(journalActionsProvider).add(_todayKey, text);
    _controller.clear();
    ref.invalidate(journalEntriesProvider(_todayKey));
    ref.invalidate(journalDatesProvider);
    setState(() => _hasUnsaved = false);
  }

  @override
  Widget build(BuildContext context) {
    // Invalidate on each sync success
    ref.listen(syncStatusProvider, (prev, next) {
      final now = next.valueOrNull;
      if (now != null && now.status == SyncStatus.success) {
        ref.invalidate(journalEntriesProvider(_todayKey));
        ref.invalidate(journalDatesProvider);
      }
    });
    final entriesAsync = ref.watch(journalEntriesProvider(_todayKey));
    final datesAsync = ref.watch(journalDatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_hasUnsaved)
            TextButton.icon(
              onPressed: _saveToday,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            )
          else
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: () {
                _controller.clear();
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Today's input card
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Today', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 2,
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _saveToday(),
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
          // Today's entries
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              Icon(Icons.today, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text("Today's Entries", style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('No entries yet', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                );
              }
              return Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _EntryCard(
                      entry: entry,
                      onEdit: () => _editEntry(entry),
                      onDelete: () async {
                        if (_remote != null) await ref.read(journalActionsProvider).delete(_todayKey, entry.id);
                        ref.invalidate(journalEntriesProvider(_todayKey));
                        ref.invalidate(journalDatesProvider);
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => AsyncErrorView(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(journalEntriesProvider(_todayKey)),
            ),
          ),
          // History divider
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(children: [
              const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('History', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${datesAsync.valueOrNull?.length ?? 0} days',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
          Expanded(
            child: datesAsync.when(
              data: (dates) {
                final pastDates = dates.where((d) => d != _todayKey).toList();
                if (pastDates.isEmpty) {
                  return const Center(
                    child: Text('No past entries', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: pastDates.length,
                  itemBuilder: (context, index) {
                    final dateKey = pastDates[index];
                    return _DateGroup(dateKey: dateKey);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  void _editEntry(JournalEntry entry) {
    _controller.text = entry.content;
    setState(() { _hasUnsaved = true; _editingEntryId = entry.id; });
  }
}

class _EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryCard({required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(entry.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const Spacer(),
            GestureDetector(
              onTap: onEdit,
              child: const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
            ),
          ]),
          const SizedBox(height: 6),
          Text(entry.content, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}

class _DateGroup extends ConsumerWidget {
  final String dateKey;
  const _DateGroup({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesProvider(dateKey));
    final date = DateTime.tryParse(dateKey);
    final label = date != null ? _formatDateLabel(date) : dateKey;

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.surface,
            collapsedBackgroundColor: AppColors.surface,
            iconColor: AppColors.textMuted,
            collapsedIconColor: AppColors.textMuted,
            title: Row(children: [
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text('${entries.length}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
            children: entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 36,
                  child: Text(DateFormat('HH:mm').format(e.createdAt),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.content,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
                ),
              ]),
            )).toList(),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${DateFormat('EEEE').format(date)} (${diff}d ago)';
    return DateFormat('MMMM d, yyyy').format(date);
  }
}
