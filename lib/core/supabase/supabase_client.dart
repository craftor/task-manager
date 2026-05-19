import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/secure_credentials_service.dart';

class AppSupabaseClient {
  static final Supabase _instance = Supabase.instance;
  static final _secureCredentials = SecureCredentialsService();

  static Future<void> initialize() async {
    // Try secure storage first
    var url = await _secureCredentials.getSupabaseUrl();
    var anonKey = await _secureCredentials.getSupabaseAnonKey();

    // Fall back to .env for initial setup, then migrate to secure storage
    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      await dotenv.load(fileName: '.env');
      url = dotenv.env['SUPABASE_URL'] ?? url;
      anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? anonKey;

      // Migrate to secure storage for future runs
      if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
        await _secureCredentials.saveSupabaseUrl(url);
        await _secureCredentials.saveSupabaseAnonKey(anonKey);
      }
    }

    if (url == null || url.isEmpty) {
      throw Exception('Missing SUPABASE_URL. Please configure in settings.');
    }
    if (anonKey == null || anonKey.isEmpty) {
      throw Exception('Missing SUPABASE_ANON_KEY. Please configure in settings.');
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  /// Called once during first launch / onboarding to store credentials securely
  static Future<void> configure({
    required String url,
    required String anonKey,
  }) async {
    await _secureCredentials.saveSupabaseUrl(url);
    await _secureCredentials.saveSupabaseAnonKey(anonKey);
  }

  static Supabase get instance => _instance;
}