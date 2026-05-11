import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://ozbxlqffizhllybonfpu.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96YnhscWZmaXpobGx5Ym9uZnB1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MTM2MTUsImV4cCI6MjA5MzI4OTYxNX0.pGWSJo-GMI_U8DYk9D0rw7PcgFYFR8aXMR_rYCJnt1M';
}

class AppSupabaseClient {
  static final Supabase _instance = Supabase.instance;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  static Supabase get instance => _instance;
}
