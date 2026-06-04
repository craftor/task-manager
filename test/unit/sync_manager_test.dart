import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:task_manager/features/sync/data/sync_manager.dart';
import 'package:task_manager/data/datasources/local/app_database.dart';
import 'package:task_manager/data/datasources/remote/remote_datasource.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockRemoteDatasource extends Mock implements RemoteDatasource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncManager', () {
    late MockAppDatabase mockDb;
    late MockRemoteDatasource mockDs;

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      mockDb = MockAppDatabase();
      mockDs = MockRemoteDatasource();

      when(() => mockDb.getPendingProjects()).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTasks()).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTimeEntries()).thenAnswer((_) async => []);
      when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
      when(() => mockDb.getAllProjects()).thenAnswer((_) async => []);

      when(() => mockDs.fetchProjects()).thenAnswer((_) async => []);
      when(() => mockDs.fetchTasks()).thenAnswer((_) async => []);
      when(() => mockDs.fetchTimeEntries()).thenAnswer((_) async => []);
      when(() => mockDs.fetchSpecialDays()).thenAnswer((_) async => []);
      when(() => mockDs.fetchJournalEntries()).thenAnswer((_) async => []);
      when(() => mockDs.fetchMoods()).thenAnswer((_) async => []);

      when(() => mockDb.markProjectSynced(any())).thenAnswer((_) async {});
      when(() => mockDb.markTaskSynced(any())).thenAnswer((_) async {});
      when(() => mockDb.markTimeEntrySynced(any())).thenAnswer((_) async {});
      when(() => mockDb.upsertProjectFromRemote(any())).thenAnswer((_) async {});
      when(() => mockDb.upsertTaskFromRemote(any())).thenAnswer((_) async {});
      when(() => mockDb.upsertTimeEntryFromRemote(any())).thenAnswer((_) async {});
      when(() => mockDb.deleteProjectById(any())).thenAnswer((_) async {});
      when(() => mockDb.deleteTaskById(any())).thenAnswer((_) async {});
      when(() => mockDb.fixLegacyTaskProject(any())).thenAnswer((_) async {});
      when(() => mockDb.cleanupDuplicateDefaultProjects()).thenAnswer((_) async {});
    });

    test('syncStateStream is accessible', () async {
      final manager = SyncManager(mockDb, mockDs);
      expect(manager.syncStateStream, isNotNull);
      manager.dispose();
    });

    test('dispose does not throw', () async {
      final manager = SyncManager(mockDb, mockDs);
      expect(() => manager.dispose(), returnsNormally);
    });
  });
}