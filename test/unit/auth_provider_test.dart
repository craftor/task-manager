import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:task_manager/features/auth/domain/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  group('AuthNotifier', () {
    late MockAuthService mockAuthService;

    setUpAll(() {
      registerFallbackValue(Uri.parse('https://example.com'));
    });

    setUp(() async {
      mockAuthService = MockAuthService();
      SharedPreferences.setMockInitialValues({});
    });

    test('initial auth state is unauthenticated when no user', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

      final notifier = AuthNotifier(mockAuthService);
      expect(notifier.state.status, AuthStatus.unauthenticated);
      notifier.dispose();
    });

    test('initial auth state is authenticated when user exists', () async {
      when(() => mockAuthService.currentUser).thenReturn(_MockUser());
      when(() => mockAuthService.onAuthStateChange).thenAnswer((_) => const Stream.empty());

      final notifier = AuthNotifier(mockAuthService);
      expect(notifier.state.status, AuthStatus.authenticated);
      notifier.dispose();
    });

    test('signIn transitions to loading then authenticated on success', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.onAuthStateChange).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.success(_MockUser()));

      final notifier = AuthNotifier(mockAuthService);
      await notifier.signIn('test@example.com', 'password123');

      expect(notifier.state.status, AuthStatus.authenticated);
      notifier.dispose();
    });

    test('signIn transitions to error on failure', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.onAuthStateChange).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.failure('Invalid credentials'));

      final notifier = AuthNotifier(mockAuthService);
      await notifier.signIn('test@example.com', 'wrongpassword');

      expect(notifier.state.status, AuthStatus.error);
      expect(notifier.state.errorMessage, 'Invalid credentials');
      notifier.dispose();
    });

    test('signUp transitions to loading then authenticated on success', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.onAuthStateChange).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.signUp(any(), any()))
          .thenAnswer((_) async => AuthResult.success(_MockUser()));

      final notifier = AuthNotifier(mockAuthService);
      await notifier.signUp('test@example.com', 'password123');

      expect(notifier.state.status, AuthStatus.authenticated);
      notifier.dispose();
    });

    test('signOut transitions to unauthenticated', () async {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.onAuthStateChange).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      final notifier = AuthNotifier(mockAuthService);
      await notifier.signOut();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      notifier.dispose();
    });
  });
}

class _MockUser extends Mock implements User {}