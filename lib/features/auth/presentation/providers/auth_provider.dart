import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? email;
  final String? avatarUrl;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.email,
    this.avatarUrl,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? email,
    String? avatarUrl,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
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
    _loadAvatar();
    _initAuthState();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('user_avatar');
    if (avatar != null) {
      state = state.copyWith(avatarUrl: avatar);
    }
  }

  void _initAuthState() {
    final user = _authService.currentUser;
    if (user != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: user.email,
        avatarUrl: state.avatarUrl,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    _authService.onAuthStateChange.listen((event) {
      final user = event.session?.user;
      if (user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          email: user.email,
          avatarUrl: state.avatarUrl,
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
    if (result.success) {
      state = AuthState(
        status: AuthStatus.authenticated,
        email: result.user?.email,
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
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}