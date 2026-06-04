import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_user.dart';
import 'auth_event.dart';
import 'auth_service.dart';

/// Supabase implementation of [AuthService]. Kept alive during the
/// migration so the existing data path continues to work; the actual cutover
/// to Appwrite happens when `kUseAppwrite` flips in
/// `remote_datasource_factory.dart`.
class SupabaseAuthService implements AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  bool _initialized = false;
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final user = _auth.currentUser;
    if (user != null) {
      _controller.add(AuthSignedInEvent(
        AppUser(id: user.id, email: user.email ?? ''),
      ));
    }
  }

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) return AuthResult.failure('Sign-in succeeded but no user returned');
      final appUser = AppUser(id: user.id, email: user.email ?? '');
      _controller.add(AuthSignedInEvent(appUser));
      return AuthResult.success(appUser);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  @override
  Future<AuthResult> signUp(String email, String password) async {
    try {
      final response = await _auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) return AuthResult.failure('Sign-up succeeded but no user returned');
      final appUser = AppUser(id: user.id, email: user.email ?? '');
      _controller.add(AuthSignedInEvent(appUser));
      return AuthResult.success(appUser);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _controller.add(const AuthSignedOutEvent());
  }

  @override
  AppUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return AppUser(id: u.id, email: u.email ?? '');
  }

  @override
  bool get isAuthenticated => _auth.currentUser != null;

  @override
  Stream<AuthEvent> get onAuthStateChange => _controller.stream;
}
