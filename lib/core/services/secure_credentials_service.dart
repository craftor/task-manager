import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving sensitive credentials.
/// Uses FlutterSecureStorage which encrypts data using AES-256.
class SecureCredentialsService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _supabaseUrlKey = 'supabase_url';
  static const _supabaseAnonKeyKey = 'supabase_anon_key';

  /// Save Supabase URL (non-sensitive but env-specific)
  Future<void> saveSupabaseUrl(String url) async {
    await _storage.write(key: _supabaseUrlKey, value: url);
  }

  /// Get Supabase URL
  Future<String?> getSupabaseUrl() async {
    return _storage.read(key: _supabaseUrlKey);
  }

  /// Save Supabase anonymous key (sensitive)
  Future<void> saveSupabaseAnonKey(String anonKey) async {
    await _storage.write(key: _supabaseAnonKeyKey, value: anonKey);
  }

  /// Get Supabase anonymous key
  Future<String?> getSupabaseAnonKey() async {
    return _storage.read(key: _supabaseAnonKeyKey);
  }

  /// Delete all stored credentials
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check if credentials exist
  Future<bool> hasCredentials() async {
    final url = await getSupabaseUrl();
    final key = await getSupabaseAnonKey();
    return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
  }
}