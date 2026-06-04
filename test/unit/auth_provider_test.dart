import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/auth/domain/app_user.dart';
import 'package:task_manager/features/auth/domain/auth_service.dart';
import 'package:task_manager/features/auth/presentation/providers/auth_provider.dart';

class MockAuthService extends Mock implements AuthService {}

const _kTestUser = AppUser(id: 'u1', email: 'test@example.com');

void main() {
  group('AuthNotifier', () {
    late MockAuthService mockAuthService;

    setUp(() async {
      mockAuthService = MockAuthService();
      SharedPreferences.setMockInitialValues({});
      when(() => mockAuthService.initialize()).thenAnswer((_) async {});
      when(() => mockAuthService.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
    });

    /// Wait for `_initAuthState` to settle, then return the notifier.
    Future<AuthNotifier> buildNotifier() async {
      final notifier = AuthNotifier(mockAuthService);
      // Let the async _initAuthState complete (it awaits initialize() and
      // then resolves the initial state from currentUser).
      await Future<void>.delayed(Duration.zero);
      return notifier;
    }

    test('initial auth state is unauthenticated when no user', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);

      final notifier = await buildNotifier();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      notifier.dispose();
    });

    test('initial auth state is authenticated when user exists', () async {
      when(() => mockAuthService.currentUser).thenReturn(_kTestUser);

      final notifier = await buildNotifier();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.userId, 'u1');
      notifier.dispose();
    });

    test('signIn transitions to loading then authenticated on success', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.success(_kTestUser));

      final notifier = await buildNotifier();
      await notifier.signIn('test@example.com', 'password123');

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.userId, 'u1');
      notifier.dispose();
    });

    test('signIn transitions to error on failure', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.failure('Invalid credentials'));

      final notifier = await buildNotifier();
      await notifier.signIn('test@example.com', 'wrongpassword');

      expect(notifier.state.status, AuthStatus.error);
      expect(notifier.state.errorMessage, 'Invalid credentials');
      notifier.dispose();
    });

    test('signUp transitions to loading then authenticated on success', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signUp(any(), any()))
          .thenAnswer((_) async => AuthResult.success(_kTestUser));

      final notifier = await buildNotifier();
      await notifier.signUp('test@example.com', 'password123');

      expect(notifier.state.status, AuthStatus.authenticated);
      notifier.dispose();
    });

    test('signOut transitions to unauthenticated', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      final notifier = await buildNotifier();
      await notifier.signOut();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      notifier.dispose();
    });
  });
}
