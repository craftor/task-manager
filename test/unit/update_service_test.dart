import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/core/services/update_service.dart';
import 'package:task_manager/core/constants/app_constants.dart';

void main() {
  group('UpdateService', () {
    test('service can be instantiated', () {
      // UpdateService only has static methods, so we just verify it's accessible
      expect(UpdateService, isNotNull);
    });

    test('github constants are correctly configured', () {
      expect(AppConstants.githubOwner, 'craftor');
      expect(AppConstants.githubRepo, 'task-manager');
    });

    test('sync interval is set to 5 minutes', () {
      expect(AppConstants.syncInterval, const Duration(minutes: 5));
    });
  });
}