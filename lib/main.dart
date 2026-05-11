import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase/supabase_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSupabaseClient.initialize();
  runApp(
    const ProviderScope(
      child: TaskManagerApp(),
    ),
  );
}