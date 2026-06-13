import 'package:appwrite/appwrite.dart';

/// Build the standard user-scoped query string list for every Appwrite
/// fetch. Appwrite SDK 21.4.0's `listDocuments` accepts `List<String>`
/// (each entry is a serialized Query JSON), so we return strings.
/// Centralized so the security invariant ("every row partitioned by
/// `user_id`") can't drift between call sites.
List<String> buildUserScopedQueries(String userId, {String? orderBy}) {
  return [
    Query.equal('user_id', userId),
    if (orderBy != null) orderBy,
  ];
}

/// Convenience: user scope + `deleted_at IS NULL` + `order by $createdAt asc`.
/// Used by projects and tasks.
List<String> buildLiveUserScopedQueries(String userId) => [
      Query.equal('user_id', userId),
      Query.isNull('deleted_at'),
      Query.orderAsc(r'$createdAt'),
    ];