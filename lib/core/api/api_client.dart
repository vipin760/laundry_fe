import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
   static const String _defaultBaseUrl = 'https://api.laundrybrew.com/'; // prod
  // static const String _defaultBaseUrl = 'https://gttzm872-3000.inc1.devtunnels.ms/'; // vipin
  // static const String _defaultBaseUrl = 'https://nvl2rk2s-3000.inc1.devtunnels.ms/'; // vipin
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _configuredBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  static late CookieJar cookieJar;

  /// Called when any API request returns 401 (token expired / revoked).
  /// Wire this up in main.dart to call authProvider.forceLogout().
  static void Function()? onUnauthorized;

  static Future<void> init() async {
    // Allows cookies to work with Dio, for web Dio / Browser automatically handle this
    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = appDocDir.path;
      cookieJar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage('$appDocPath/.cookies/'),
      );
      _dio.interceptors.add(CookieManager(cookieJar));
    }

    // Global 401 interceptor — clears token and triggers logout when an
    // *authenticated* request is rejected by the server.
    //
    // A 401 on a request that never carried an Authorization header just
    // means we tried to call a protected endpoint before login/restore
    // finished (e.g. a cart fetch racing app-start token restoration on
    // web refresh) — that is not a session being revoked, so it must not
    // trigger forceLogout(). Treating it as one would wipe a token that
    // was mid-restore, and (because forceLogout() invalidates the very
    // provider that just failed) create an unbounded retry loop.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) {
          if (error.response?.statusCode == 401) {
            final hadAuthHeader =
                error.requestOptions.headers['Authorization'] != null;
            clearToken();
            if (hadAuthHeader) {
              onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static Dio get instance => _dio;

  static String get baseUrl => _configuredBaseUrl;

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    if (!kIsWeb) {
      await cookieJar.deleteAll();
    }
  }
}
