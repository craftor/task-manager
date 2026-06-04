import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/datasources/remote/remote_datasource_factory.dart';
import '../../domain/auth_event.dart';
import '../../domain/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? email;

  /// User id of the authenticated user. Used by `sync_status_provider` to
  /// build the `RemoteDatasource` (Appwrite / Supabase row partition key).
  /// Null when unauthenticated / loading.
  final String? userId;
  final String? avatarUrl;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.email,
    this.userId,
    this.avatarUrl,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? email,
    String? userId,
    String? avatarUrl,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
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

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  StreamSubscription? _authSubscription;

  AuthNotifier(this._authService) : super(const AuthState(status: AuthStatus.loading)) {
    _loadAvatar();
    _initAuthState();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('user_avatar');
    if (avatar != null && mounted) {
      state = state.copyWith(avatarUrl: avatar);
    }
  }

  Future<void> _initAuthState() async {
    await _authService.initialize();
    if (!mounted) return;
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
      if (!mounted) return;
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await _authService.signInWithEmail(email, password);
    if (!mounted) return;
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
        userId: result.user?.id,
        avatarUrl: state.avatarUrl,
      );
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result.error,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await _authService.signUp(email, password);
    if (!mounted) return;
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
        userId: result.user?.id,
        avatarUrl: state.avatarUrl,
      );
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result.error,
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
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
