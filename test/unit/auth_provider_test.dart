import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('LocalAuthNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      // Let the async _loadFromPrefs finish on the empty store.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(() {
      container.dispose();
    });

    test('default state has userId="local"', () {
      final state = container.read(authStateProvider);
      expect(state.userId, 'local');
      expect(state.email, isNull);
      expect(state.avatarUrl, isNull);
    });

    test('setEmail persists and updates state', () async {
      await container
          .read(authStateProvider.notifier)
          .setEmail('alice');
      final state = container.read(authStateProvider);
      expect(state.email, 'alice');

      // Wait for c1's setEmail to finish writing to SharedPreferences.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // A fresh container reads back the same value.
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      // Trigger build() by reading the notifier — this is what kicks
      // off _loadFromPrefs.
      c2.read(authStateProvider);
      // _loadFromPrefs is fire-and-forget; allow it to finish.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c2.read(authStateProvider).email, 'alice');
    });

    test('setEmail(null) clears the stored nickname', () async {
      await container
          .read(authStateProvider.notifier)
          .setEmail('alice');
      await container
          .read(authStateProvider.notifier)
          .setEmail(null);
      expect(container.read(authStateProvider).email, isNull);
    });

    test('updateAvatar / removeAvatar round-trips', () async {
      await container
          .read(authStateProvider.notifier)
          .updateAvatar('C:/avatars/me.png');
      // The notifier writes to SharedPreferences asynchronously; give
      // the microtask queue a turn to drain before asserting.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(authStateProvider).avatarUrl, 'C:/avatars/me.png');

      await container
          .read(authStateProvider.notifier)
          .removeAvatar();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(authStateProvider).avatarUrl, isNull);
    });
  });
}
