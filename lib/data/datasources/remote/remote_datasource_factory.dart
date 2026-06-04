import '../../../core/appwrite/appwrite_client.dart';
import '../../../features/auth/domain/appwrite_auth_service.dart';
import '../../../features/auth/domain/auth_service.dart';
import 'appwrite_datasource.dart';
import 'remote_datasource.dart';

/// Appwrite database id used by every [AppwriteDatasource] instance.
const String kAppwriteDatabaseId = '6a20eeaa002f0f294ab9';

/// Build the [AuthService] backed by the global Appwrite client.
AuthService buildAuthService() => AppwriteAuthService();

/// Build the appropriate [RemoteDatasource] for the current build flag.
///
/// When [userId] is null (no signed-in user), returns null — call sites
/// already handle this case.
RemoteDatasource? buildRemoteDatasource({required String? userId}) {
  if (userId == null) return null;
  return AppwriteDatasource(client, userId, kAppwriteDatabaseId);
}
