/// Domain representation of an authenticated user.
///
/// Decouples the auth layer from any specific backend SDK so callers (and
/// tests) never need to import `package:supabase_flutter` or
/// `package:appwrite` to reason about "the current user".
class AppUser {
  final String id;
  final String email;

  const AppUser({required this.id, required this.email});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser && other.id == id && other.email == email);

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'AppUser(id: $id, email: $email)';
}
