import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock service — stores the PIN using PBKDF2-HMAC-SHA256 with a random
/// per-install salt, persisted via [FlutterSecureStorage] (Android Keystore /
/// iOS Keychain). The legacy SHA-256 + static-salt hash kept in
/// SharedPreferences is migrated lazily on first read.
class AppLockService {
  AppLockService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _saltKey = 'app_lock_salt';
  static const String _hashKey = 'app_lock_pin_hash';
  static const String _enabledKey = 'app_lock_enabled';
  // Legacy keys — only present on installs that ran the previous version.
  static const String _legacyPinKey = 'app_lock_pin';

  static const int _pbkdf2Iterations = 100000;
  static const int _hashLengthBytes = 32;
  static const int _saltLengthBytes = 32;

  final FlutterSecureStorage _secureStorage;

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Hash [pin] with a fresh random salt and persist both to secure storage.
  /// The enabled flag is also flipped on in SharedPreferences.
  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = _pbkdf2(pin, salt);
    await _secureStorage.write(key: _saltKey, value: base64Encode(salt));
    await _secureStorage.write(key: _hashKey, value: base64Encode(hash));
    await setLockEnabled(true);
  }

  Future<void> removePin() async {
    await _secureStorage.delete(key: _saltKey);
    await _secureStorage.delete(key: _hashKey);
    await setLockEnabled(false);
  }

  /// Verify [input] against the stored hash. Also performs a one-shot
  /// migration of any legacy SHA-256 + static-salt hash left in
  /// SharedPreferences — that hash is wiped and the lock disabled,
  /// forcing the user to re-enroll on next use.
  Future<bool> verifyPin(String input) async {
    final migrated = await _migrateLegacyIfPresent();
    if (migrated) {
      // Legacy install: lock is now off. No PIN to verify against.
      return false;
    }
    final saltB64 = await _secureStorage.read(key: _saltKey);
    final hashB64 = await _secureStorage.read(key: _hashKey);
    if (saltB64 == null || hashB64 == null) return false;
    final salt = base64Decode(saltB64);
    final expected = base64Decode(hashB64);
    final candidate = _pbkdf2(input, salt);
    return _constantTimeEquals(candidate, expected);
  }

  /// If the legacy `app_lock_pin` (SharedPreferences) is still present,
  /// wipe it, disable the lock, and return true so the caller can prompt
  /// the user to re-enroll. Returns false when no legacy data exists.
  Future<bool> _migrateLegacyIfPresent() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPinKey);
    if (legacy == null) return false;
    await prefs.remove(_legacyPinKey);
    await prefs.setBool(_enabledKey, false);
    // Secure storage may already hold a new-format hash — leave it alone.
    return true;
  }

  Uint8List _randomSalt() {
    final rng = Random.secure();
    final bytes = Uint8List(_saltLengthBytes);
    for (var i = 0; i < _saltLengthBytes; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  Uint8List _pbkdf2(String pin, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _hashLengthBytes));
    final pinBytes = Uint8List.fromList(utf8.encode(pin));
    return derivator.process(pinBytes);
  }

  /// Constant-time byte comparison to avoid leaking length-mismatch timing
  /// info during PIN verification.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Reproduces the legacy SHA-256 + static-salt hash so tests can verify
/// migration behavior without leaking the legacy salt into prod code.
String legacyAppLockHash(String pin) {
  final bytes = utf8.encode('TaskManagerAppLock_v1$pin');
  return sha256.convert(bytes).toString();
}