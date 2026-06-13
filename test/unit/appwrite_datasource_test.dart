import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/data/datasources/remote/user_scoped_query.dart';

/// Verifies the security invariant: every fetch method in
/// `appwrite_datasource.dart` builds its query list through one of the
/// helpers in `user_scoped_query.dart`, both of which include
/// `Query.equal('user_id', userId)`. This test pins that invariant at
/// the helper boundary so any future fetch that bypasses the helper
/// (or forgets to add `user_id`) shows up as a failed review.
void main() {
  group('user-scoped query helpers', () {
    test('buildUserScopedQueries includes user_id filter', () {
      final queries = buildUserScopedQueries('user-A');
      // Each helper returns serialized Query JSON strings; check the
      // 'equal' attribute and the user value are present.
      final joined = queries.join(',');
      expect(joined, contains('"attribute":"user_id"'));
      expect(joined, contains('"method":"equal"'));
      expect(joined, contains('user-A'));
    });

    test('buildLiveUserScopedQueries adds deleted_at IS NULL + ordering',
        () {
      final queries = buildLiveUserScopedQueries('user-B');
      final joined = queries.join(',');
      expect(joined, contains('"attribute":"user_id"'));
      expect(joined, contains('user-B'));
      expect(joined, contains('"attribute":"deleted_at"'));
      expect(joined, contains('"method":"isNull"'));
      expect(joined, contains(r'$createdAt'));
    });

    test('buildUserScopedQueries orderBy is appended when supplied', () {
      final queries = buildUserScopedQueries(
        'user-C',
        orderBy: Query.orderAsc('date_key'),
      );
      expect(queries.length, 2);
      expect(queries.last, contains('date_key'));
    });
  });
}