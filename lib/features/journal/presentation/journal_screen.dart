import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../journal/journal_provider.dart';
import '../../journal/journal_service.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _controller = TextEditingController();
  final _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _hasUnsaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadToday());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    final note = await ref.read(journalServiceProvider).getNote(_todayKey);
    if (mounted && note != null) {
      _controller.text = note;
    }
  }

  Future<void> _saveToday() async {
    await ref.read(journalServiceProvider).saveNote(_todayKey, _controller.text);
    ref.invalidate(journalNotesProvider);
    setState(() => _hasUnsaved = false);
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(journalNotesProvider);

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
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
                      color: AppColors.primary.withOpacity(0.12),
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
                  minLines: 3,
                  onChanged: (_) {
                    if (!_hasUnsaved) setState(() => _hasUnsaved = true);
                  },
                  decoration: const InputDecoration(
                    hintText: 'What\'s on your mind today?',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
          // History
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('History', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${notesAsync.valueOrNull?.length ?? 0} entries',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
          Expanded(
            child: notesAsync.when(
              data: (notes) {
                final entries = notes.entries.toList()
                  ..sort((a, b) => b.key.compareTo(a.key));
                final pastEntries = entries.where((e) => e.key != _todayKey).toList();

                if (pastEntries.isEmpty) {
                  return const Center(
                    child: Text('No past entries yet',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: pastEntries.length,
                  itemBuilder: (context, index) {
                    final entry = pastEntries[index];
                    final date = DateTime.tryParse(entry.key);
                    final label = date != null ? _formatDateLabel(date) : entry.key;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: AppColors.surface,
                        collapsedBackgroundColor: AppColors.surface,
                        iconColor: AppColors.textMuted,
                        collapsedIconColor: AppColors.textMuted,
                        title: Text(
                          label,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          _preview(entry.value, 60),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.value,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6)),
                                const SizedBox(height: 10),
                                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _controller.text = entry.value;
                                      setState(() => _hasUnsaved = true);
                                    },
                                    icon: const Icon(Icons.content_copy, size: 16),
                                    label: const Text('Load into today'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    onPressed: () async {
                                      await ref.read(journalServiceProvider).deleteNote(entry.key);
                                      ref.invalidate(journalNotesProvider);
                                    },
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
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

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final dayName = DateFormat('EEEE').format(date);
    if (diff < 7) return '$dayName (${diff}d ago)';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _preview(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}
