import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'journal_service.dart';

final journalServiceProvider = Provider<JournalService>((ref) => JournalService());

/// All dates that have journal entries
final journalDatesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(journalServiceProvider);
  return service.getAllDates();
});

/// Entries for a specific date
final journalEntriesProvider = FutureProvider.family<List<JournalEntry>, String>((ref, dateKey) async {
  final service = ref.watch(journalServiceProvider);
  return service.getEntries(dateKey);
});
