/// Local-auth state holder.
///
/// After the Appwrite removal there is no server-side auth. This
/// provider exists to keep the existing UI surface (avatar / email /
/// userId) working without forcing every callsite to be rewritten.
///
/// New writes (signIn / signUp) are intentionally NOT exposed — the
/// email/password flow is gone. The app launches directly into the
/// dashboard, gated only by [appLockEnabledProvider].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  const AuthState({
    this.email,
    this.userId,
    this.avatarUrl,
  });

  /// Optional local "display name". Empty by default; the user can set
  /// it from the settings screen to personalize the avatar.
  final String? email;

  /// Stable identifier for this installation. Always the literal
  /// "local" — exists so the WebDAV pipeline and any legacy code
  /// expecting a non-null user id keeps working.
  final String? userId;

  /// Path to a user-picked avatar image, stored in SharedPreferences.
  final String? avatarUrl;

  static const empty = AuthState(userId: 'local');

  AuthState copyWith({
    String? email,
    String? userId,
    String? avatarUrl,
  }) {
    return AuthState(
      email: email ?? this.email,
      userId: userId ?? this.userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

final authStateProvider = NotifierProvider<LocalAuthNotifier, AuthState>(
  LocalAuthNotifier.new,
);

class LocalAuthNotifier extends Notifier<AuthState> {
  static const _kAvatarKey = 'user_avatar';
  static const _kEmailKey = 'user_email';

  @override
  AuthState build() {
    _loadFromPrefs();
    return AuthState.empty;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString(_kAvatarKey);
    final email = prefs.getString(_kEmailKey);
    if (avatar == null && email == null) return;
    state = AuthState(
      email: email,
      userId: state.userId,
      avatarUrl: avatar,
    );
  }

  Future<void> setEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(_kEmailKey);
    } else {
      await prefs.setString(_kEmailKey, email);
    }
    state = AuthState(
      email: email,
      userId: state.userId,
      avatarUrl: state.avatarUrl,
    );
  }

  Future<void> updateAvatar(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAvatarKey, imagePath);
    state = AuthState(
      email: state.email,
      userId: state.userId,
      avatarUrl: imagePath,
    );
  }

  Future<void> removeAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAvatarKey);
    state = AuthState(
      email: state.email,
      userId: state.userId,
      avatarUrl: null,
    );
  }
}
