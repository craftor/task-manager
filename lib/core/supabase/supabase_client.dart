import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
}

class SupabaseClient {
  static final Supabase _instance = Supabase.instance;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  static SupabaseClient get instance => _instance;
  SupabaseClient get client => _instance.client;

  static AuthClient get auth => _instance.client.auth;
  static DatabaseClient get database => _instance.client;
}
