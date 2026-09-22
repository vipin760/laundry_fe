import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laudry_app/core/services/secure_session_store.dart';

/// In-memory stand-in for the platform keystore.
///
/// [failing] simulates a device where the keystore is unusable (corrupted
/// Android keystore, locked keychain, browser with crypto disabled) — the path
/// that must degrade gracefully rather than crash app start.
class _FakeSecureStorage extends FlutterSecureStoragePlatform
    with MockPlatformInterfaceMixin {
  _FakeSecureStorage({this.failing = false});

  final bool failing;
  final Map<String, String> store = <String, String>{};

  void _guard() {
    if (failing) throw Exception('keystore unavailable');
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _guard();
    store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    _guard();
    return store[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    _guard();
    return store.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _guard();
    store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    _guard();
    return Map<String, String>.from(store);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _guard();
    store.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorage fake;

  setUp(() {
    fake = _FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = fake;
    SharedPreferences.setMockInitialValues({});
    SecureSessionStore.debugResetAvailability();
  });

  group('SecureSessionStore (BUG-009)', () {
    test('round-trips a session through secure storage', () async {
      await SecureSessionStore.saveSession(
        token: 'jwt-abc',
        userJson: '{"mobileNumber":"+919876543210"}',
      );

      expect(await SecureSessionStore.readToken(), 'jwt-abc');
      expect(await SecureSessionStore.readUserJson(),
          '{"mobileNumber":"+919876543210"}');
      expect(fake.store[SecureSessionStore.tokenKey], 'jwt-abc');
    });

    test('no stored session reads as null rather than throwing', () async {
      expect(await SecureSessionStore.readToken(), isNull);
      expect(await SecureSessionStore.readUserJson(), isNull);
    });

    test('migrates a legacy plaintext session instead of signing the user out',
        () async {
      // A session written by a pre-upgrade build.
      SharedPreferences.setMockInitialValues({
        SecureSessionStore.tokenKey: 'legacy-jwt',
        SecureSessionStore.userKey: '{"mobileNumber":"+911111111111"}',
      });

      // The upgraded app must still see the user as signed in...
      expect(await SecureSessionStore.readToken(), 'legacy-jwt');

      // ...with the value now held in secure storage...
      expect(fake.store[SecureSessionStore.tokenKey], 'legacy-jwt');

      // ...and the plaintext copy removed.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureSessionStore.tokenKey), isNull);
    });

    test('keeps the plaintext copy when the secure write fails', () async {
      // Losing the only copy of a valid session would sign the user out for
      // good, so migration must not delete before it has stored.
      SharedPreferences.setMockInitialValues({
        SecureSessionStore.tokenKey: 'legacy-jwt',
      });
      FlutterSecureStoragePlatform.instance = _FakeSecureStorage(failing: true);
      SecureSessionStore.debugResetAvailability();

      expect(await SecureSessionStore.readToken(), 'legacy-jwt');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureSessionStore.tokenKey), 'legacy-jwt');
    });

    test('an unusable keystore degrades instead of throwing', () async {
      FlutterSecureStoragePlatform.instance = _FakeSecureStorage(failing: true);
      SecureSessionStore.debugResetAvailability();

      // None of these may throw — they run during app start.
      await expectLater(
        SecureSessionStore.saveSession(token: 't', userJson: '{}'),
        completes,
      );
      await expectLater(SecureSessionStore.readToken(), completion(isNull));
      await expectLater(SecureSessionStore.clear(), completes);
      expect(SecureSessionStore.secureStorageUnavailable, isTrue);
    });

    test('clear removes both the secure and any legacy copy', () async {
      SharedPreferences.setMockInitialValues({
        SecureSessionStore.tokenKey: 'legacy-jwt',
        SecureSessionStore.userKey: 'legacy-user',
      });
      await SecureSessionStore.saveSession(token: 'jwt', userJson: '{}');

      await SecureSessionStore.clear();

      expect(fake.store, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureSessionStore.tokenKey), isNull);
      expect(prefs.getString(SecureSessionStore.userKey), isNull);
      expect(await SecureSessionStore.readToken(), isNull);
    });

    test('saving a session clears any leftover plaintext copy', () async {
      SharedPreferences.setMockInitialValues({
        SecureSessionStore.tokenKey: 'stale-plaintext',
      });

      await SecureSessionStore.saveSession(token: 'fresh', userJson: '{}');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureSessionStore.tokenKey), isNull);
      expect(await SecureSessionStore.readToken(), 'fresh');
    });
  });
}
