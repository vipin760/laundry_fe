import 'package:shared_preferences/shared_preferences.dart';

/// Captures and persists a referral code that arrived via a deep link or
/// `?ref=CODE` install URL, so it survives until the user finishes registering.
///
/// Flow:
///  1. App opened from `https://appname.com/register?ref=LBX8JQ2` (or a custom
///     scheme deep link). The router/link handler calls [capture].
///  2. On the registration screen, [pendingCode] pre-fills the referral field.
///  3. Immediately after successful registration, apply the code via
///     ReferralApi.apply(...) and then call [clear].
///
/// Wire your deep-link plugin (e.g. app_links / uni_links / Firebase Dynamic
/// Links) to call [captureFromUri] with the incoming URI.
class ReferralDeepLinkService {
  static const _key = 'pending_referral_code';

  /// Extract `ref` from an incoming URI and persist it if present.
  static Future<void> captureFromUri(Uri uri) async {
    final code = uri.queryParameters['ref'] ?? uri.queryParameters['code'];
    if (code != null && code.trim().isNotEmpty) {
      await capture(code.trim().toUpperCase());
    }
  }

  static Future<void> capture(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  /// The captured code, if any (used to pre-fill the registration field).
  static Future<String?> pendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    return (code == null || code.isEmpty) ? null : code;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
