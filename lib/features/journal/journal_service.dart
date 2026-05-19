import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/remote/supabase_datasource.dart';

class JournalEntry {
  final String id;
  final DateTime createdAt;
  final String content;

  const JournalEntry({required this.id, required this.createdAt, required this.content});

  Map<String, dynamic> toJson() => {'id': id, 'created_at': createdAt.toIso8601String(), 'content': content};
  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String, createdAt: DateTime.parse(json['created_at'] as String), content: json['content'] as String);
}

class JournalService {
  static const String _cacheKey = 'journal_cache';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get entries for a date from local cache
  Future<List<JournalEntry>> getEntries(String dateKey) async {
    final all = await _loadCache();
    return all[dateKey] ?? [];
  }

  /// Add entry — writes to local cache then fire-and-forget to remote
  Future<JournalEntry> addEntry(SupabaseDatasource remote, String dateKey, String content) async {
    final entry = JournalEntry(id: const Uuid().v4(), createdAt: DateTime.now(), content: content.trim());
    final all = await _loadCache();
    all.putIfAbsent(dateKey, () => []).insert(0, entry);
    await _saveCache(all);

    remote.upsertJournalEntry(dateKey, entry.toJson()).catchError((e) {
      Logger.d('JournalService.addEntry: remote failed - $e');
    });
    return entry;
  }

  /// Delete entry from local cache + remote
  Future<void> deleteEntry(SupabaseDatasource remote, String dateKey, String entryId) async {
    final all = await _loadCache();
    all[dateKey]?.removeWhere((e) => e.id == entryId);
    if (all[dateKey]?.isEmpty == true) all.remove(dateKey);
    await _saveCache(all);

    remote.deleteJournalEntry(entryId).catchError((e) {
      Logger.d('JournalService.deleteEntry: remote failed - $e');
    });
  }

  /// Get all dates that have entries
  Future<List<String>> getAllDates() async {
    final all = await _loadCache();
    final dates = all.keys.toList()..sort((a, b) => b.compareTo(a));
    return dates;
  }

  /// Pull all from remote and replace local cache
  Future<void> pullFromRemote(SupabaseDatasource remote) async {
    try {
      final rows = await remote.fetchJournalEntries();
      final map = <String, List<JournalEntry>>{};
      for (final row in rows) {
        final key = row['date_key'] as String?;
        if (key == null) continue;
        map.putIfAbsent(key, () => []).add(JournalEntry.fromJson(row));
      }
      await _saveCache(map);
      Logger.d('JournalService: pulled ${rows.length} entries from remote');
    } catch (e) {
      Logger.d('JournalService.pullFromRemote: $e');
    }
  }

  // ── private ──
  Future<Map<String, List<JournalEntry>>> _loadCache() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as List).map((e) => JournalEntry.fromJson(e)).toList()));
    } catch (_) { return {}; }
  }

  Future<void> _saveCache(Map<String, List<JournalEntry>> data) async {
    final prefs = await _preferences;
    await prefs.setString(_cacheKey, json.encode(data.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()))));
  }
}
