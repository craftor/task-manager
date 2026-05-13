import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JournalService {
  static const String _key = 'journal_notes';

  Future<Map<String, String>> getAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  Future<String?> getNote(String dateKey) async {
    final notes = await getAllNotes();
    return notes[dateKey];
  }

  Future<void> saveNote(String dateKey, String content) async {
    final notes = await getAllNotes();
    if (content.trim().isEmpty) {
      notes.remove(dateKey);
    } else {
      notes[dateKey] = content.trim();
    }
    await _save(notes);
  }

  Future<void> deleteNote(String dateKey) async {
    final notes = await getAllNotes();
    notes.remove(dateKey);
    await _save(notes);
  }

  Future<List<MapEntry<String, String>>> getRecentNotes(int limit) async {
    final notes = await getAllNotes();
    final entries = notes.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries.take(limit).toList();
  }

  Future<void> _save(Map<String, String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(notes));
  }
}
