import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../features/auth/domain/appwrite_auth_service.dart';
import '../../../features/auth/domain/auth_service.dart';
import '../../../features/auth/domain/supabase_auth_service.dart';
import 'appwrite_datasource.dart';
import 'remote_datasource.dart';
import 'supabase_datasource.dart';

/// Compile-time switch between the Supabase and Appwrite implementations of
/// the auth + data layers. Phase A–C.5 keep this `false`; flipping to `true`
/// in Phase C.6 is the actual cutover.
///
/// Why compile-time and not runtime: the Appwrite project id, endpoint, and
/// database id are baked into the binary. A runtime switch would need a
/// remote config layer that's out of scope for v1.
const bool kUseAppwrite = true;

/// Appwrite database id used by every [AppwriteDatasource] instance.
/// Must match the database created in the Appwrite console during Phase C setup.
const String kAppwriteDatabaseId = '6a20eeaa002f0f294ab9';

/// Build the appropriate [AuthService] for the current build flag.
AuthService buildAuthService() {
  return kUseAppwrite ? AppwriteAuthService() : SupabaseAuthService();
}

/// Build the appropriate [RemoteDatasource] for the current build flag.
///
/// When [userId] is null (no signed-in user), returns null — call sites
/// already handle this case.
RemoteDatasource? buildRemoteDatasource({required String? userId}) {
  if (userId == null) return null;
  return kUseAppwrite
      ? AppwriteDatasource(client, userId, kAppwriteDatabaseId)
      : SupabaseDatasource(Supabase.instance.client, userId);
}
