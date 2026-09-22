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

    // Global 401 interceptor — clears the session and triggers logout when an
    // *authenticated* request is rejected by the server.
    //
    // A 401 on a request that never carried an Authorization header just
    // means we tried to call a protected endpoint before login/restore
    // finished (e.g. a cart fetch racing app-start token restoration on
    // web refresh) — that is not a session being revoked. Such a response is
    // left entirely alone: clearing credentials here would wipe a token that
    // was mid-restore and strand the app in a state where it still looks
    // signed in while every subsequent request goes out unauthenticated (and,
    // carrying no header, keeps failing this same way forever).
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401) {
            final hadAuthHeader =
                error.requestOptions.headers['Authorization'] != null;

            // Several authenticated requests can be in flight when a token is
            // revoked; they must not each tear the session down in turn.
            if (hadAuthHeader && !_handlingUnauthorized) {
              _handlingUnauthorized = true;
              await clearToken();
              onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Guards against concurrent 401s each triggering their own forced logout.
  /// Reset by [setToken], so a newly established session starts clean.
  static bool _handlingUnauthorized = false;

  static Dio get instance => _dio;

  static String get baseUrl => _configuredBaseUrl;

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    _handlingUnauthorized = false;
  }

  static Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    if (!kIsWeb) {
      await cookieJar.deleteAll();
    }
  }
}
