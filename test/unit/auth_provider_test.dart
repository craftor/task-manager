import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    late ProviderContainer container;

    setUp(() async {
      mockAuthService = MockAuthService();
      SharedPreferences.setMockInitialValues({});
      when(() => mockAuthService.initialize()).thenAnswer((_) async {});
      when(() => mockAuthService.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());

      container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
      ]);
      // Let the async _initAuthState complete.
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> settleAuth() async {
      // Wait until _initAuthState finishes (status leaves `loading`).
      for (var i = 0; i < 20; i++) {
        if (container.read(authStateProvider).status != AuthStatus.loading) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('initial auth state is unauthenticated when no user', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      container.invalidate(authStateProvider);
      await settleAuth();
      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('initial auth state is authenticated when user exists', () async {
      when(() => mockAuthService.currentUser).thenReturn(_kTestUser);
      container.invalidate(authStateProvider);
      await settleAuth();
      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'u1');
    });

    test('signIn transitions to loading then authenticated on success',
        () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.success(_kTestUser));

      await container.read(authStateProvider.notifier)
          .signIn('test@example.com', 'password123');

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'u1');
    });

    test('signIn transitions to error on failure', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signInWithEmail(any(), any())).thenAnswer(
          (_) async => AuthResult.failure('Invalid credentials',
              failureKind: AuthFailureKind.invalidCredentials));

      await container.read(authStateProvider.notifier)
          .signIn('test@example.com', 'wrongpassword');

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Invalid credentials');
      expect(state.failureKind, AuthFailureKind.invalidCredentials);
    });

    test('signUp transitions to loading then authenticated on success',
        () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signUp(any(), any()))
          .thenAnswer((_) async => AuthResult.success(_kTestUser));

      await container.read(authStateProvider.notifier)
          .signUp('test@example.com', 'password123');

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.authenticated);
    });

    test('signOut transitions to unauthenticated', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      await container.read(authStateProvider.notifier).signOut();

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });
  });
}