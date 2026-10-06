import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/data/sync/webdav/webdav_credentials.dart';

void main() {
  group('WebDavCredentials.isValid', () {
    test('rejects empty / partial inputs', () {
      expect(const WebDavCredentials(baseUrl: '', username: '', password: '').isValid, isFalse);
      expect(
        const WebDavCredentials(
          baseUrl: 'https://dav.example.com',
          username: 'u',
          password: '',
        ).isValid,
        isFalse,
      );
      expect(
        const WebDavCredentials(
          baseUrl: 'https://dav.example.com',
          username: '',
          password: 'p',
        ).isValid,
        isFalse,
      );
    });

    test('rejects malformed / unsupported URLs', () {
      expect(
        const WebDavCredentials(
          baseUrl: 'not-a-url',
          username: 'u',
          password: 'p',
        ).isValid,
        isFalse,
      );
      expect(
        const WebDavCredentials(
          baseUrl: 'ftp://example.com',
          username: 'u',
          password: 'p',
        ).isValid,
        isFalse,
      );
    });

    test('accepts valid http(s) URLs', () {
      expect(
        const WebDavCredentials(
          baseUrl: 'https://dav.example.com',
          username: 'u',
          password: 'p',
        ).isValid,
        isTrue,
      );
      expect(
        const WebDavCredentials(
          baseUrl: 'http://localhost:8080',
          username: 'u',
          password: 'p',
        ).isValid,
        isTrue,
      );
    });
  });

  group('WebDavCredentials.toMap / fromMap', () {
    test('round-trips without the password', () {
      const c = WebDavCredentials(
        baseUrl: 'https://dav.example.com',
        username: 'alice',
        password: 's3cret',
        remotePath: '/dav',
      );
      final map = c.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map['baseUrl'], 'https://dav.example.com');
      expect(map['remotePath'], '/dav');

      final restored = WebDavCredentials.fromMap({
        ...map,
        'password': '', // never stored, but fromMap tolerates it
      });
      expect(restored.baseUrl, c.baseUrl);
      expect(restored.username, c.username);
      expect(restored.remotePath, c.remotePath);
    });
  });
}
