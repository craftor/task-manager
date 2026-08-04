import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/journal/data/journal_repository_impl.dart';
import 'package:task_manager/features/mood/data/mood_repository_impl.dart';
import 'package:task_manager/features/special_days/data/special_days_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalRepositoryImpl applyRemote*', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('applyRemoteUpsertEntry inserts a new entry into the cache',
        () async {
      final repo = JournalRepositoryImpl();
      await repo.applyRemoteUpsertEntry('2026-08-04', {
        'id': 'entry-1',
        'created_at': DateTime.utc(2026, 8, 4, 10).toIso8601String(),
        'content': 'Realtime-delivered journal entry',
      });

      final entries = await repo.getEntries('2026-08-04');
      expect(entries, hasLength(1));
      expect(entries.first.id, 'entry-1');
      expect(entries.first.content, 'Realtime-delivered journal entry');
    });

    test('applyRemoteUpsertEntry updates an existing entry by id', () async {
      final repo = JournalRepositoryImpl();
      await repo.applyRemoteUpsertEntry('2026-08-04', {
        'id': 'entry-1',
        'created_at': DateTime.utc(2026, 8, 4, 10).toIso8601String(),
        'content': 'original',
      });
      await repo.applyRemoteUpsertEntry('2026-08-04', {
        'id': 'entry-1',
        'created_at': DateTime.utc(2026, 8, 4, 11).toIso8601String(),
        'content': 'updated',
      });

      final entries = await repo.getEntries('2026-08-04');
      expect(entries, hasLength(1));
      expect(entries.first.content, 'updated');
    });

    test('applyRemoteDeleteEntry removes the matching entry and drops empty date',
        () async {
      final repo = JournalRepositoryImpl();
      await repo.applyRemoteUpsertEntry('2026-08-04', {
        'id': 'entry-1',
        'created_at': DateTime.utc(2026, 8, 4, 10).toIso8601String(),
        'content': 'to-delete',
      });

      await repo.applyRemoteDeleteEntry('2026-08-04', 'entry-1');
      final entries = await repo.getEntries('2026-08-04');
      expect(entries, isEmpty);

      final dates = await repo.getAllDates();
      expect(dates, isNot(contains('2026-08-04')));
    });
  });

  group('MoodRepositoryImpl applyRemote*', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('applyRemoteMood writes the per-date key', () async {
      final repo = MoodRepositoryImpl();
      await repo.applyRemoteMood('2026-08-04', '["😊","🎉"]');
      final emojis = await repo.getMoods('2026-08-04');
      expect(emojis, ['😊', '🎉']);
    });

    test('applyRemoteDeleteMood removes the per-date key', () async {
      final repo = MoodRepositoryImpl();
      await repo.applyRemoteMood('2026-08-04', '["😊"]');
      await repo.applyRemoteDeleteMood('2026-08-04');
      final emojis = await repo.getMoods('2026-08-04');
      expect(emojis, isEmpty);
    });
  });

  group('SpecialDaysRepositoryImpl applyRemote*', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('applyRemoteDay writes the per-date key', () async {
      final repo = SpecialDaysRepositoryImpl();
      await repo.applyRemoteDay('2026-08-04', '{"color":"2","desc":"anniversary"}');
      final day = await repo.getDay('2026-08-04');
      expect(day, isNotNull);
      expect(day!['color'], '2');
      expect(day['desc'], 'anniversary');
    });

    test('applyRemoteDeleteDay removes the per-date key', () async {
      final repo = SpecialDaysRepositoryImpl();
      await repo.applyRemoteDay('2026-08-04', '{"color":"0"}');
      await repo.applyRemoteDeleteDay('2026-08-04');
      final day = await repo.getDay('2026-08-04');
      expect(day, isNull);
    });
  });
}
