import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/datasources/remote/remote_datasource_factory.dart';
import '../../domain/auth_event.dart';
import '../../domain/auth_service.dart' show AuthFailureKind, AuthService;

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final AuthFailureKind? failureKind;
  final String? email;
  final String? userId;
  final String? avatarUrl;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.failureKind,
    this.email,
    this.userId,
    this.avatarUrl,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    AuthFailureKind? failureKind,
    String? email,
    String? userId,
    String? avatarUrl,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      failureKind: clearError ? null : (failureKind ?? this.failureKind),
      email: email ?? this.email,
      userId: userId ?? this.userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

/// Holds the active [AuthService] for the current build. Selected by
/// `kUseAppwrite` in `remote_datasource_factory.dart`; tests can override
/// via [authServiceProvider.overrideWithValue].
final authServiceProvider = Provider<AuthService>((ref) {
  return buildAuthService();
});

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  StreamSubscription? _authSubscription;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    _loadAvatar();
    _initAuthState();
    ref.onDispose(() {
      _authSubscription?.cancel();
    });
    return const AuthState(status: AuthStatus.loading);
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('user_avatar');
    if (avatar != null) {
      state = state.copyWith(avatarUrl: avatar);
    }
  }

  Future<void> _initAuthState() async {
    await _authService.initialize();
    final user = _authService.currentUser;
    if (user != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: user.email,
        userId: user.id,
        avatarUrl: state.avatarUrl,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    _authSubscription = _authService.onAuthStateChange.listen((event) {
      if (event is AuthSignedInEvent) {
        state = AuthState(
          status: AuthStatus.authenticated,
          email: event.user.email,
          userId: event.user.id,
          avatarUrl: state.avatarUrl,
        );
      } else if (event is AuthSignedOutEvent) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final result = await _authService.signInWithEmail(email, password);
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
        userId: result.user?.id,
        avatarUrl: state.avatarUrl,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: result.error,
        failureKind: result.failureKind,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final result = await _authService.signUp(email, password);
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
        userId: result.user?.id,
        avatarUrl: state.avatarUrl,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: result.error,
        failureKind: result.failureKind,
      );
    }
  }

  Future<void> updateAvatar(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', imagePath);
    state = state.copyWith(avatarUrl: imagePath);
  }

  Future<void> removeAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_avatar');
    state = state.copyWith(avatarUrl: null);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}