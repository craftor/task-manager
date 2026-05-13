import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const specialDayColors = const [
  0xFFE91E63,
  0xFFFF5722,
  0xFF4CAF50,
  0xFF2196F3,
  0xFFFF9800,
  0xFF9C27B0,
];

class SpecialDaysService {
  static const String _key = 'special_days_map';

  /// Get all special days as Map<dateKey, json encoded {color, desc}>
  Future<Map<String, Map<String, String>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k,
        (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2 as String))));
  }

  /// Get parsed color index for a date, or null
  Future<int?> getColorIndex(String dateKey) async {
    final all = await getAll();
    final data = all[dateKey];
    if (data == null) return null;
    return int.tryParse(data['color'] ?? '0');
  }

  Future<String?> getDescription(String dateKey) async {
    final all = await getAll();
    return all[dateKey]?['desc'];
  }

  Future<void> setDay(String dateKey, int colorIndex, String? description) async {
    final all = await getAll();
    all[dateKey] = {
      'color': colorIndex.toString(),
      if (description != null && description.isNotEmpty) 'desc': description,
    };
    await _save(all);
  }

  Future<void> removeDay(String dateKey) async {
    final all = await getAll();
    all.remove(dateKey);
    await _save(all);
  }

  Future<List<DateTime>> getSortedDates() async {
    final all = await getAll();
    final dates = all.keys
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList();
    dates.sort();
    return dates;
  }

  Future<void> _save(Map<String, Map<String, String>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(data));
  }
}
