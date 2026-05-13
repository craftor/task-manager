import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'journal_service.dart';

final journalServiceProvider = Provider<JournalService>((ref) => JournalService());

final journalNotesProvider = FutureProvider<Map<String, String>>((ref) async {
  final service = ref.watch(journalServiceProvider);
  return service.getAllNotes();
});
