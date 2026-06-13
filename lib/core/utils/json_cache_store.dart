import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Generic JSON-on-SharedPreferences key/value store. Centralizes the
/// `_prefs` singleton + load/save boilerplate that journal/mood/
/// special_days used to duplicate.
class JsonCacheStore {
  JsonCacheStore(this._key);

  final String _key;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsAsync async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Read the raw JSON string for this key.
  Future<String?> readRaw() async {
    final prefs = await _prefsAsync;
    return prefs.getString(_key);
  }

  /// Write the raw JSON string for this key.
  Future<void> writeRaw(String value) async {
    final prefs = await _prefsAsync;
    await prefs.setString(_key, value);
  }

  /// Remove the entry entirely.
  Future<void> clear() async {
    final prefs = await _prefsAsync;
    await prefs.remove(_key);
  }

  /// Decode the stored value as JSON. Returns `null` on missing/corrupt.
  Future<dynamic> readJson() async {
    final raw = await readRaw();
    if (raw == null) return null;
    try {
      return json.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Encode [value] as JSON and persist.
  Future<void> writeJson(Object value) => writeRaw(json.encode(value));
}