import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/secure_credentials_service.dart';

class AppSupabaseClient {
  static final Supabase _instance = Supabase.instance;
  static final _secureCredentials = SecureCredentialsService();

  static Future<void> initialize() async {
    // First try secure storage (primary source after first launch)
    var url = await _secureCredentials.getSupabaseUrl();
    var anonKey = await _secureCredentials.getSupabaseAnonKey();

    // If secure storage is empty, try loading from assets config (for initial setup)
    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      try {
        final configString = await rootBundle.loadString('assets/flutter_assets/assets/config.json');
        final config = json.decode(configString) as Map<String, dynamic>;
        url = config['SUPABASE_URL'] as String? ?? url;
        anonKey = config['SUPABASE_ANON_KEY'] as String? ?? anonKey;

        // Migrate to secure storage for future runs
        if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
          await _secureCredentials.saveSupabaseUrl(url);
          await _secureCredentials.saveSupabaseAnonKey(anonKey);
        }
      } catch (e) {
        // Asset loading failed - will fall through to error check
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