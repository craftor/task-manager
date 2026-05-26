import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const String _pinKey = 'app_lock_pin';
  static const String _enabledKey = 'app_lock_enabled';
  static const String _salt = 'TaskManagerAppLock_v1';

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _hashPin(pin);
    await prefs.setString(_pinKey, hashed);
    await prefs.setBool(_enabledKey, true);
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_enabledKey, false);
  }

  Future<bool> verifyPin(String input) async {
    final stored = await SharedPreferences.getInstance().then((p) => p.getString(_pinKey));
    if (stored == null) return false;
    return stored == _hashPin(input);
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(_salt + pin);
    return sha256.convert(bytes).toString();
  }
}
