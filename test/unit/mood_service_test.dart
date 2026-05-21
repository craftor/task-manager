import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/mood/mood_service.dart';
import 'package:task_manager/data/datasources/remote/supabase_datasource.dart';

class MockSupabaseDatasource extends Mock implements SupabaseDatasource {}

void main() {
  group('MoodService', () {
    late MockSupabaseDatasource mockDs;

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      mockDs = MockSupabaseDatasource();
      // Reset static cache to ensure fresh SharedPreferences per test
      SharedPreferences.setMockInitialValues({});
    });

    test('setMoods stores moods locally and syncs to remote', () async {
      when(() => mockDs.upsertMood(any(), any()))
          .thenAnswer((_) async {});

      final service = MoodService();
      await service.setMoods(mockDs, '2024-01-01', ['😊', '😢']);

      final moods = await service.getMoods('2024-01-01');
      expect(moods, ['😊', '😢']);

      verify(() => mockDs.upsertMood('2024-01-01', any())).called(1);
    });

    test('removeMoods removes moods from cache and syncs to remote', () async {
      SharedPreferences.setMockInitialValues({
        'moods_cache': json.encode({
          '2024-01-01': ['😊', '😢']
        })
      });

      when(() => mockDs.deleteMood(any()))
          .thenAnswer((_) async {});

      final service = MoodService();
      await service.removeMoods(mockDs, '2024-01-01');

      final moods = await service.getMoods('2024-01-01');
      expect(moods, isEmpty);

      verify(() => mockDs.deleteMood('2024-01-01')).called(1);
    });

    test('getMoods returns empty list when no moods for date', () async {
      final service = MoodService();
      final moods = await service.getMoods('2024-01-01');
      expect(moods, isEmpty);
    });

    test('setMoods does not throw even when remote fails', () async {
      when(() => mockDs.upsertMood(any(), any()))
          .thenThrow(Exception('Network error'));

      final service = MoodService();

      // Should not throw - errors are caught internally
      expect(() => service.setMoods(mockDs, '2024-01-01', ['😊']), returnsNormally);

      // Allow async to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('mergeRemoteData replaces local cache with remote data', () async {
      SharedPreferences.setMockInitialValues({
        'moods_cache': json.encode({
          '2024-01-01': ['😊']
        })
      });

      final remoteRows = [
        {'date_key': '2024-01-02', 'data': '["😡","😴"]'},
        {'date_key': '2024-01-03', 'data': '["❤️"]'},
      ];

      await MoodService.mergeRemoteData(remoteRows);

      // Verify cache was updated
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('moods_cache');
      expect(cached, isNotNull);

      final decoded = json.decode(cached!) as Map<String, dynamic>;
      expect(decoded['2024-01-02'], ['😡', '😴']);
      expect(decoded['2024-01-03'], ['❤️']);
    });
  });
}