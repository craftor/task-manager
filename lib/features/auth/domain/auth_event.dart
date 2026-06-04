import 'app_user.dart';

/// Events emitted by [AuthService] on sign-in / sign-out / session change.
///
/// Supabase's `AuthState` and Appwrite's account notifications are not
/// directly compatible, so the auth layer projects both into this single
/// sealed type. Consumers branch on the subtype.
sealed class AuthEvent {
  const AuthEvent();
}

/// Fired after a successful `signInWithEmail` or `signUp`, or when the
/// persisted session is rehydrated at app start.
class AuthSignedInEvent extends AuthEvent {
  final AppUser user;
  const AuthSignedInEvent(this.user);
}

/// Fired after a successful `signOut` or when the persisted session is
/// detected as gone (e.g. cookie expired) at app start.
class AuthSignedOutEvent extends AuthEvent {
  const AuthSignedOutEvent();
}
