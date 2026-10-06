/// Stub for the deleted `remote_datasource_factory.dart`.
///
/// All previous entry points returned an Appwrite-backed
/// [RemoteDatasource]. With Appwrite gone, every public function now
/// returns a [NoopRemote]. Kept so the `buildRemoteDatasource(userId:)`
/// callsite in the sync provider keeps compiling.
library;

import 'remote_datasource.dart';

export 'remote_datasource.dart';

/// Always returns a no-op remote. The `userId` argument is ignored —
/// the WebDAV pipeline doesn't need per-user scoping because each
/// installation has its own user-scoped WebDAV folder.
RemoteDatasource buildRemoteDatasource({String? userId}) =>
    const NoopRemote();
