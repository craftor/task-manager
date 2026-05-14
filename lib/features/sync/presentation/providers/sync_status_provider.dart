import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../data/datasources/remote/supabase_datasource.dart';
import '../../data/sync_manager.dart';

final userIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.status != AuthStatus.authenticated) return null;
  return Supabase.instance.client.auth.currentUser?.id;
});

final supabaseDatasourceProvider = Provider<SupabaseDatasource?>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return null;
  return SupabaseDatasource(Supabase.instance.client, userId);
});

final syncManagerProvider = Provider<SyncManager?>((ref) {
  final db = ref.watch(databaseProvider);
  final datasource = ref.watch(supabaseDatasourceProvider);
  if (datasource == null) return null;

  final manager = SyncManager(db, datasource);
  ref.onDispose(() => manager.dispose());
  return manager;
});

final syncStatusProvider = StreamProvider<SyncState>((ref) {
  // Read (not watch) to avoid creating new manager instances on each access
  final manager = ref.read(syncManagerProvider);
  if (manager == null) return const Stream.empty();
  return manager.syncStateStream;
});
