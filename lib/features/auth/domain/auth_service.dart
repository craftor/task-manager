import 'app_user.dart';
import 'auth_event.dart';

/// Result of an authentication attempt.
class AuthResult {
  final bool success;
  final String? error;
  final AppUser? user;

  AuthResult.success(this.user) : success = true, error = null;
  AuthResult.failure(this.error) : success = false, user = null;
}

/// Backend-agnostic auth surface.
///
/// Implemented by [AppwriteAuthService] (replaces the deleted
/// SupabaseAuthService from the Supabase → Appwrite migration).
abstract class AuthService {
  /// Read any persisted session and emit an [AuthEvent] for it. Idempotent.
  Future<void> initialize();

  Future<AuthResult> signInWithEmail(String email, String password);

  Future<AuthResult> signUp(String email, String password);

  Future<void> signOut();

  AppUser? get currentUser;
  bool get isAuthenticated;

  /// Stream of auth state changes, projected to our domain [AuthEvent] type.
  Stream<AuthEvent> get onAuthStateChange;
}
