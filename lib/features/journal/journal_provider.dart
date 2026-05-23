import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'journal_service.dart';

final journalServiceProvider = Provider<JournalService>((ref) => JournalService());

final journalDatesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(journalServiceProvider);
  return service.getAllDates();
});

final journalEntriesProvider = FutureProvider.family<List<JournalEntry>, String>((ref, dateKey) async {
  final service = ref.watch(journalServiceProvider);
  return service.getEntries(dateKey);
});
