import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class JournalEntry {
  final String id;
  final DateTime createdAt;
  final String content;

  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'content': content,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    content: json['content'] as String,
  );
}

class JournalService {
  static const String _keyPrefix = 'journal_';

  Future<List<JournalEntry>> getEntries(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$dateKey');
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addEntry(String dateKey, String content) async {
    final entries = await getEntries(dateKey);
    entries.insert(0, JournalEntry(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      content: content.trim(),
    ));
    await _save(dateKey, entries);
  }

  Future<void> updateEntry(String dateKey, String entryId, String content) async {
    final entries = await getEntries(dateKey);
    final idx = entries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    entries[idx] = JournalEntry(
      id: entryId,
      createdAt: entries[idx].createdAt,
      content: content.trim(),
    );
    await _save(dateKey, entries);
  }

  Future<void> deleteEntry(String dateKey, String entryId) async {
    final entries = await getEntries(dateKey);
    entries.removeWhere((e) => e.id == entryId);
    await _save(dateKey, entries);
  }

  /// Get all dates that have entries, sorted newest first.
  Future<List<String>> getAllDates() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    return keys
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => k.substring(_keyPrefix.length))
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  /// Get total entry count for a date
  Future<int> getEntryCount(String dateKey) async {
    final entries = await getEntries(dateKey);
    return entries.length;
  }

  Future<void> _save(String dateKey, List<JournalEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$dateKey', json.encode(entries.map((e) => e.toJson()).toList()));
  }
}
