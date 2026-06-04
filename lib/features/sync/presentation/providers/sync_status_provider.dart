import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../data/datasources/remote/remote_datasource.dart';
import '../../../../data/datasources/remote/remote_datasource_factory.dart';
import '../../data/sync_manager.dart';

/// Current authenticated user id. Sourced from the auth state (set during
/// `AuthNotifier._initAuthState`) so this provider stays backend-agnostic.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).userId;
});

/// Backend-agnostic remote datasource (Supabase today, Appwrite in Phase C).
///
/// Returns null when no user is signed in. The implementation is selected
/// by `kUseAppwrite` in `remote_datasource_factory.dart`.
final remoteDatasourceProvider = Provider<RemoteDatasource?>((ref) {
  final userId = ref.watch(userIdProvider);
  return buildRemoteDatasource(userId: userId);
});

// Singleton instance holder to prevent multiple SyncManager instances
// Multiple instances would cause duplicate periodic syncs and connectivity listeners
class _SyncManagerHolder {
  static SyncManager? _instance;
  static void set(SyncManager? m) => _instance = m;
  static SyncManager? get() => _instance;
}

final syncManagerProvider = Provider<SyncManager?>((ref) {
  // Return existing singleton if already created
  if (_SyncManagerHolder.get() != null) return _SyncManagerHolder.get();

  final db = ref.watch(databaseProvider);
  final datasource = ref.watch(remoteDatasourceProvider);
  if (datasource == null) return null;

  final manager = SyncManager(db, datasource);
  _SyncManagerHolder.set(manager);

  ref.onDispose(() {
    manager.dispose();
    _SyncManagerHolder.set(null);
  });

  return manager;
});

final syncStatusProvider = StreamProvider<SyncState>((ref) {
  // Read (not watch) to avoid creating new manager instances on each access
  final manager = ref.read(syncManagerProvider);
  if (manager == null) return const Stream.empty();
  return manager.syncStateStream;
});
