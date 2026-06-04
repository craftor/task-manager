import 'dart:async';

import 'package:appwrite/appwrite.dart';
import '../../../core/appwrite/appwrite_client.dart';
import 'app_user.dart';
import 'auth_event.dart';
import 'auth_service.dart';

/// Appwrite implementation of [AuthService].
///
/// Uses the global [client] from `lib/core/appwrite/appwrite_client.dart`
/// unless an [Account] is injected (test override). Sessions are managed by
/// the Appwrite SDK's internal cookie_jar — we just project the events into
/// the [AuthEvent] stream.
class AppwriteAuthService implements AuthService {
  final Account _account;
  AppUser? _cachedUser;
  bool _initialized = false;
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  AppwriteAuthService({Account? account})
      : _account = account ?? Account(client);

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final user = await _account.get();
      _cachedUser = AppUser(id: user.$id, email: user.email);
      _controller.add(AuthSignedInEvent(_cachedUser!));
    } catch (_) {
      _cachedUser = null;
    }
  }

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await _account.get();
      _cachedUser = AppUser(id: user.$id, email: user.email);
      _controller.add(AuthSignedInEvent(_cachedUser!));
      return AuthResult.success(_cachedUser!);
    } on AppwriteException catch (e) {
      return AuthResult.failure(_humanize(e));
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  @override
  Future<AuthResult> signUp(String email, String password) async {
    try {
      await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
      );
      // Appwrite's create() does not auto-create a session — sign in next.
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await _account.get();
      _cachedUser = AppUser(id: user.$id, email: user.email);
      _controller.add(AuthSignedInEvent(_cachedUser!));
      return AuthResult.success(_cachedUser!);
    } on AppwriteException catch (e) {
      return AuthResult.failure(_humanize(e));
    } catch (e) {
      return AuthResult.failure('Network error: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {
      // Best-effort — we still want to clear local state.
    }
    _cachedUser = null;
    _controller.add(const AuthSignedOutEvent());
  }

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  bool get isAuthenticated => _cachedUser != null;

  @override
  Stream<AuthEvent> get onAuthStateChange => _controller.stream;

  /// Map Appwrite error codes to user-friendly messages. Falls back to the
  /// raw message if no translation is found.
  String _humanize(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Invalid email or password.';
      case 409:
        return 'An account with this email already exists.';
      case 429:
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Auth error (code ${e.code}).';
    }
  }
}
