import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SpecialDaysService {
  static const String _key = 'special_days';

  /// Get all special date strings (yyyy-MM-dd)
  Future<Set<String>> getSpecialDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return {};
    return raw.toSet();
  }

  /// Toggle a date as special
  Future<void> toggleDay(String dateKey) async {
    final days = await getSpecialDays();
    if (days.contains(dateKey)) {
      days.remove(dateKey);
    } else {
      days.add(dateKey);
    }
    await _save(days);
  }

  /// Check if a date is special
  Future<bool> isSpecial(String dateKey) async {
    final days = await getSpecialDays();
    return days.contains(dateKey);
  }

  /// Get special days for a specific year
  Future<Set<String>> getSpecialDaysForYear(int year) async {
    final days = await getSpecialDays();
    final prefix = '$year-';
    return days.where((d) => d.startsWith(prefix)).toSet();
  }

  /// Get sorted list of special dates
  Future<List<DateTime>> getSortedDates() async {
    final days = await getSpecialDays();
    final dates = days
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList();
    dates.sort();
    return dates;
  }

  /// Get intervals between special days in chronological order
  Future<List<Duration>> getIntervals() async {
    final dates = await getSortedDates();
    if (dates.length < 2) return [];
    final intervals = <Duration>[];
    for (var i = 1; i < dates.length; i++) {
      intervals.add(dates[i].difference(dates[i - 1]));
    }
    return intervals;
  }

  Future<void> _save(Set<String> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, days.toList());
  }
}
