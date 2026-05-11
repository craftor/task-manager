import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResult {
  final bool success;
  final String? error;
  final User? user;

  AuthResult.success(this.user) : success = true, error = null;
  AuthResult.failure(this.error) : success = false, user = null;
}

class AuthService {
  final Supabase _client;

  AuthService(this._client);

  AuthClient get _auth => _client.auth;

  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return AuthResult.success(response.user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    }
  }

  Future<AuthResult> signUp(String email, String password) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
      );
      return AuthResult.success(response.user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  Stream<User?> get onAuthStateChange => _auth.onAuthStateChange.map(
        (event) => event.session?.user,
      );
}
