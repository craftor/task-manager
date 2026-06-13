import 'package:intl/intl.dart';

/// Canonical `yyyy-MM-dd` key used throughout the app to bucket journal
/// entries, moods, and special days by date. The same format is written
/// to Appwrite as the `date_key` attribute.
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Inverse of [dateKey]. Returns `null` for malformed strings rather than
/// throwing — callers (UI date labels, mood distribution charts) should
/// treat `null` as "skip this row".
DateTime? parseDateKey(String key) {
  try {
    return DateFormat('yyyy-MM-dd').parseStrict(key);
  } catch (_) {
    return null;
  }
}