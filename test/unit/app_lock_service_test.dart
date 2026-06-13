import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/features/auth/domain/app_lock_service.dart';

/// In-memory fake of [FlutterSecureStorage] for unit tests. Only the
/// methods AppLockService uses are implemented.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeSecureStorage: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService', () {
    late AppLockService service;
    late FakeSecureStorage fakeStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeStorage = FakeSecureStorage();
      service = AppLockService(secureStorage: fakeStorage);
    });

    test('isLockEnabled defaults to false', () async {
      expect(await service.isLockEnabled(), isFalse);
    });

    test('setPin then verifyPin with same PIN succeeds', () async {
      await service.setPin('1234');
      expect(await service.verifyPin('1234'), isTrue);
      expect(await service.isLockEnabled(), isTrue);
    });

    test('verifyPin with wrong PIN fails', () async {
      await service.setPin('1234');
      expect(await service.verifyPin('9999'), isFalse);
    });

    test('removePin clears lock state', () async {
      await service.setPin('1234');
      await service.removePin();
      expect(await service.isLockEnabled(), isFalse);
      expect(await service.verifyPin('1234'), isFalse);
    });

    test('two installs use different salts for the same PIN', () async {
      // First install
      await service.setPin('1234');
      final salt1 = await fakeStorage.read(key: 'app_lock_salt');
      final hash1 = await fakeStorage.read(key: 'app_lock_pin_hash');

      // Fresh storage to simulate a new install.
      fakeStorage._store.clear();
      SharedPreferences.setMockInitialValues({});
      final fresh = AppLockService(secureStorage: fakeStorage);
      await fresh.setPin('1234');
      final salt2 = await fakeStorage.read(key: 'app_lock_salt');
      final hash2 = await fakeStorage.read(key: 'app_lock_pin_hash');

      // Same PIN → different salt → different hash. This is the
      // property that defeats dictionary attacks on a single hash.
      expect(salt1, isNotNull);
      expect(salt2, isNotNull);
      expect(salt1, isNot(equals(salt2)));
      expect(hash1, isNot(equals(hash2)));
    });

    test('legacy SHA-256 hash is migrated to a disabled state', () async {
      // Simulate an old install with the static-salt hash.
      final legacyHash = legacyAppLockHash('1234');
      SharedPreferences.setMockInitialValues({
        'app_lock_pin': legacyHash,
        'app_lock_enabled': true,
      });
      // verifyPin should detect the legacy key, wipe it, and return
      // false (lock is now off — user must re-enroll).
      expect(await service.verifyPin('1234'), isFalse);
      // Confirm the legacy key is gone.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_lock_pin'), isNull);
      expect(prefs.getBool('app_lock_enabled'), isFalse);
    });
  });
}