import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:task_manager/data/datasources/local/app_database.dart';
import 'package:task_manager/data/datasources/remote/remote_datasource.dart';
import 'package:task_manager/features/journal/domain/journal_repository.dart';
import 'package:task_manager/features/mood/domain/mood_repository.dart';
import 'package:task_manager/features/special_days/domain/special_days_repository.dart';
import 'package:task_manager/features/sync/data/sync_manager.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockRemoteDatasource extends Mock implements RemoteDatasource {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockMoodRepository extends Mock implements MoodRepository {}

class MockSpecialDaysRepository extends Mock implements SpecialDaysRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncManager', () {
    late MockAppDatabase mockDb;
    late MockRemoteDatasource mockDs;
    late MockJournalRepository mockJournal;
    late MockMoodRepository mockMood;
    late MockSpecialDaysRepository mockSpecialDays;

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(MockRemoteDatasource());
    });

    setUp(() {
      mockDb = MockAppDatabase();
      mockDs = MockRemoteDatasource();
      mockJournal = MockJournalRepository();
      mockMood = MockMoodRepository();
      mockSpecialDays = MockSpecialDaysRepository();

      when(() => mockDb.getPendingProjects()).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTasks()).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTimeEntries()).thenAnswer((_) async => []);
      when(() => mockDb.getAllProjectsIncludingDeleted())
          .thenAnswer((_) async => []);
      when(() => mockDb.getAllTasksIncludingDeleted())
          .thenAnswer((_) async => []);

      when(() => mockDs.fetchProjects()).thenAnswer((_) async => []);
      when(() => mockDs.fetchTasks()).thenAnswer((_) async => []);
      when(() => mockDs.fetchTimeEntries()).thenAnswer((_) async => []);

      when(() => mockDb.markProjectSynced(any())).thenAnswer((_) async {});
      when(() => mockDb.markTaskSynced(any())).thenAnswer((_) async {});
      when(() => mockDb.markTimeEntrySynced(any())).thenAnswer((_) async {});
      when(() => mockDb.upsertProjectFromRemote(any())).thenAnswer((_) async {});
      when(() => mockDb.upsertTaskFromRemote(any())).thenAnswer((_) async {});
      when(() => mockDb.upsertTimeEntryFromRemote(any())).thenAnswer((_) async {});
      when(() => mockDb.deleteProject(any())).thenAnswer((_) async => 0);
      when(() => mockDb.deleteTask(any())).thenAnswer((_) async => 0);

      when(() => mockJournal.pullFromRemote(any())).thenAnswer((_) async {});
      when(() => mockMood.pullFromRemote(any())).thenAnswer((_) async {});
      when(() => mockSpecialDays.pullFromRemote(any())).thenAnswer((_) async {});
    });

    SyncManager buildManager() => SyncManager(
          mockDb,
          mockDs,
          journalRepository: mockJournal,
          moodRepository: mockMood,
          specialDaysRepository: mockSpecialDays,
        );

    test('syncStateStream is accessible', () async {
      final manager = buildManager();
      expect(manager.syncStateStream, isNotNull);
      manager.dispose();
    });

    test('dispose does not throw', () async {
      final manager = buildManager();
      expect(() => manager.dispose(), returnsNormally);
    });
  });
}