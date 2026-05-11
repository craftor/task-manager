import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? email;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.email,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? email,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      email: email ?? this.email,
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _initAuthState();
  }

  void _initAuthState() {
    final user = _authService.currentUser;
    if (user != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: user.email,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    _authService.onAuthStateChange.listen((event) {
      if (event.session?.user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          email: event.session?.user?.email,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await _authService.signInWithEmail(email, password);
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
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
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
      );
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result.error,
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}