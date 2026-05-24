import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase/supabase_client.dart';
import 'core/utils/logger.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for uncaught widget exceptions
  FlutterError.onError = (details) {
    Logger.e('FlutterError: uncaught widget error', error: details.exceptionAsString(), stackTrace: details.stack);
    FlutterError.presentError(details);
  };

  try {
    await AppSupabaseClient.initialize();
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to initialize: $e', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => exit(0),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }
  runApp(
    const ProviderScope(
      child: TaskManagerApp(),
    ),
  );
}