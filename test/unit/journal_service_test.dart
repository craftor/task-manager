import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/journal/journal_service.dart';
import 'package:task_manager/data/datasources/remote/supabase_datasource.dart';

class MockSupabaseDatasource extends Mock implements SupabaseDatasource {}

void main() {
  group('JournalService', () {
    late MockSupabaseDatasource mockDs;
    late SharedPreferences prefs;

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      mockDs = MockSupabaseDatasource();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('addEntry stores entry locally and syncs to remote', () async {
      when(() => mockDs.upsertJournalEntry(any(), any()))
          .thenAnswer((_) async {});

      final service = JournalService();
      final entry = await service.addEntry(mockDs, '2024-01-01', 'Test content');

      expect(entry.content, 'Test content');
      expect(entry.id, isNotEmpty);

      // Verify remote was called
      verify(() => mockDs.upsertJournalEntry('2024-01-01', any())).called(1);
    });

    test('getEntries returns cached entries for date', () async {
      SharedPreferences.setMockInitialValues({
        'journal_cache': json.encode({
          '2024-01-01': [
            {'id': 'test-id', 'created_at': '2024-01-01T10:00:00.000', 'content': 'Test'}
          ]
        })
      });
      prefs = await SharedPreferences.getInstance();

      final service = JournalService();
      final entries = await service.getEntries('2024-01-01');

      expect(entries.length, 1);
      expect(entries.first.content, 'Test');
    });

    test('deleteEntry removes entry from cache and syncs to remote', () async {
      SharedPreferences.setMockInitialValues({
        'journal_cache': json.encode({
          '2024-01-01': [
            {'id': 'test-id', 'created_at': '2024-01-01T10:00:00.000', 'content': 'Test'}
          ]
        })
      });
      prefs = await SharedPreferences.getInstance();

      when(() => mockDs.deleteJournalEntry(any()))
          .thenAnswer((_) async {});

      final service = JournalService();
      await service.deleteEntry(mockDs, '2024-01-01', 'test-id');

      final entries = await service.getEntries('2024-01-01');
      expect(entries.length, 0);

      verify(() => mockDs.deleteJournalEntry('test-id')).called(1);
    });

    test('getAllDates returns sorted list of dates with entries', () async {
      SharedPreferences.setMockInitialValues({
        'journal_cache': json.encode({
          '2024-01-01': [{'id': '1', 'created_at': '2024-01-01T10:00:00.000', 'content': 'A'}],
          '2024-01-02': [{'id': '2', 'created_at': '2024-01-02T10:00:00.000', 'content': 'B'}],
          '2023-12-31': [{'id': '3', 'created_at': '2023-12-31T10:00:00.000', 'content': 'C'}],
        })
      });
      prefs = await SharedPreferences.getInstance();

      final service = JournalService();
      final dates = await service.getAllDates();

      expect(dates, ['2024-01-02', '2024-01-01', '2023-12-31']);
    });

    test('addEntry does not throw even when remote fails', () async {
      when(() => mockDs.upsertJournalEntry(any(), any()))
          .thenThrow(Exception('Network error'));

      final service = JournalService();

      // Should not throw - errors are caught internally
      expect(() => service.addEntry(mockDs, '2024-01-01', 'Test'), returnsNormally);

      // Allow async to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });
  });
}