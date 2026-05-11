import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sync_manager.dart';

final syncManagerProvider = Provider<SyncManager>((ref) {
  throw UnimplementedError('Initialize with actual database and datasource');
});

final syncStatusProvider = StreamProvider<SyncState>((ref) {
  final manager = ref.watch(syncManagerProvider);
  return manager.syncStateStream;
});
