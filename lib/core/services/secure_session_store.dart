import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keychain/Keystore-backed storage for the session token and cached profile.
///
/// Earlier builds kept both in plaintext `SharedPreferences`. Those values are
/// migrated on first read and the plaintext copy deleted, so upgrading users
/// keep their session instead of being silently signed out.
///
/// Every call is defensive: secure storage is backed by platform keystores
/// that can genuinely fail (corrupted Android keystore, locked keychain, a
/// browser with crypto disabled). A failure here must never crash or block
/// app start — it degrades to "no stored session", which the app already
/// handles as "signed out".
class SecureSessionStore {
  SecureSessionStore._();

  static const tokenKey = 'jwt_token';
  static const userKey = 'auth_user';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Set when the platform keystore is unusable. The session then lives only
  /// in memory for this run rather than being written back out in plaintext —
  /// the user stays signed in now and signs in again next launch.
  static bool _secureStorageUnavailable = false;

  static bool get secureStorageUnavailable => _secureStorageUnavailable;

  /// Clears the "keystore is broken" latch between tests.
  @visibleForTesting
  static void debugResetAvailability() => _secureStorageUnavailable = false;

  static Future<String?> _readSecure(String key) async {
    if (_secureStorageUnavailable) return null;
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SecureSessionStore] read failed for $key: $e');
      _secureStorageUnavailable = true;
      return null;
    }
  }

  static Future<bool> _writeSecure(String key, String value) async {
    if (_secureStorageUnavailable) return false;
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      debugPrint('[SecureSessionStore] write failed for $key: $e');
      _secureStorageUnavailable = true;
      return false;
    }
  }

  static Future<void> _deleteSecure(String key) async {
    if (_secureStorageUnavailable) return;
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureSessionStore] delete failed for $key: $e');
    }
  }

  /// Reads [key], migrating a legacy plaintext value across on first run.
  static Future<String?> _readWithMigration(String key) async {
    final secure = await _readSecure(key);
    if (secure != null && secure.isNotEmpty) return secure;

    // Nothing secure yet — fall back to the pre-upgrade plaintext copy.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy == null || legacy.isEmpty) return null;

      // Only drop the plaintext copy once it is safely stored, so a failed
      // migration can never destroy a valid session.
      final migrated = await _writeSecure(key, legacy);
      if (migrated) await prefs.remove(key);
      return legacy;
    } catch (e) {
      debugPrint('[SecureSessionStore] legacy migration failed for $key: $e');
      return null;
    }
  }

  static Future<String?> readToken() => _readWithMigration(tokenKey);

  static Future<String?> readUserJson() => _readWithMigration(userKey);

  static Future<void> saveSession({
    required String token,
    required String userJson,
  }) async {
    await _writeSecure(tokenKey, token);
    await _writeSecure(userKey, userJson);
    // Make sure no plaintext copy from a previous build lingers.
    await _removeLegacy();
  }

  static Future<void> saveUserJson(String userJson) =>
      _writeSecure(userKey, userJson).then((_) {});

  static Future<void> clear() async {
    await _deleteSecure(tokenKey);
    await _deleteSecure(userKey);
    await _removeLegacy();
  }

  static Future<void> _removeLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(userKey);
    } catch (e) {
      debugPrint('[SecureSessionStore] could not clear legacy session: $e');
    }
  }
}
