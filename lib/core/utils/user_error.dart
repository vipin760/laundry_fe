import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode;

import 'package:dio/dio.dart';

/// Turns any caught error into a message that is safe to show a customer.
///
/// Rule: users only ever see either a sentence our own code / backend wrote
/// for them, or [fallback]. Never an exception class name, error code, stack
/// trace, HTTP status, JSON, or platform message — e.g. the iOS
/// `PlatformException(error, sharePositionOrigin: ...)` that used to appear
/// under "Download Invoice".
///
/// - `Exception('Friendly text')` thrown by our services → `Friendly text`
///   (services already translate API errors into user copy before throwing).
/// - [DioException] → the server's `message` if it reads like user copy,
///   otherwise a network / server-busy message, otherwise [fallback].
/// - Anything else (PlatformException, FirebaseException, TypeError,
///   FormatException, ...) → [fallback].
///
/// Use [fallback] to say what failed, e.g. "Could not download the invoice.
/// Please try again."
String userErrorMessage(Object? error, {required String fallback}) {
  if (error == null) return fallback;

  if (error is String) return _clean(error) ?? fallback;

  if (error is DioException) return _fromDio(error) ?? fallback;

  if (error is TimeoutException) return kSlowNetworkMessage;

  final raw = error.toString();
  if (_looksLikeNoNetwork(raw)) return kNoInternetMessage;

  // Only a plain `Exception('...')` carries a message we wrote on purpose.
  const prefix = 'Exception: ';
  if (raw.startsWith(prefix)) {
    return _clean(raw.substring(prefix.length)) ?? fallback;
  }
  return fallback;
}

/// Message for a Razorpay `PaymentFailureResponse` (pass `r.code`, `r.message`).
///
/// On Android the SDK's `message` is often a raw JSON blob such as
/// `{"error":{"code":"BAD_REQUEST_ERROR","description":"..."}}` — only the
/// human `description` inside it is ever shown.
String paymentFailureMessage(int? code, String? message) {
  // razorpay_flutter: 0 = NETWORK_ERROR, 2 = PAYMENT_CANCELLED.
  if (code == 0) {
    return 'Payment could not be completed due to a network problem. Please try again.';
  }
  if (code == 2) return 'Payment cancelled.';

  String? text = message;
  if (text != null && text.trimLeft().startsWith('{')) {
    text = null;
    try {
      final decoded = jsonDecode(message!);
      if (decoded is Map) {
        final err = decoded['error'] is Map ? decoded['error'] as Map : decoded;
        final desc = err['description'];
        if (desc is String) text = desc;
      }
    } catch (_) {}
  }
  return userErrorMessage(text, fallback: 'Payment failed. Please try again.');
}

const kGenericErrorMessage = 'Something went wrong. Please try again.';
const kNoInternetMessage =
    'No internet connection. Please check your network and try again.';
const kSlowNetworkMessage =
    'This is taking longer than usual. Please check your internet connection and try again.';
const kServerBusyMessage =
    'Something went wrong on our side. Please try again in a moment.';

String? _fromDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return kSlowNetworkMessage;
    case DioExceptionType.connectionError:
      return kNoInternetMessage;
    case DioExceptionType.cancel:
      return null;
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final data = e.response?.data;
  if (data is Map) {
    final msg = data['message'] ?? data['error'] ?? data['msg'];
    if (msg is String) {
      final clean = _clean(msg);
      if (clean != null) return clean;
    } else if (msg is List && msg.isNotEmpty) {
      final clean = _clean(msg.map((m) => m.toString()).join('. '));
      if (clean != null) return clean;
    }
  }

  final status = e.response?.statusCode;
  if (status == 401) return 'Your session has expired. Please log in again.';
  if (status != null && status >= 500) return kServerBusyMessage;
  if (e.type == DioExceptionType.unknown && _looksLikeNoNetwork(e.toString())) {
    return kNoInternetMessage;
  }
  return null;
}

bool _looksLikeNoNetwork(String s) =>
    s.contains('SocketException') ||
    s.contains('Failed host lookup') ||
    s.contains('Network is unreachable') ||
    s.contains('Connection refused') ||
    s.contains('Connection reset') ||
    s.contains('XMLHttpRequest error');

/// Things that only appear in developer-facing text.
final _technical = RegExp(
  r'Exception|Error:|Error\(|TypeError|NoSuchMethod|RangeError|StateError|'
  r'Bad state|Null check|subtype of|Instance of|Unhandled|errno|status code|'
  r'stack ?trace|firebase_|PlatformException|MissingPlugin|dart:|package:|'
  r'Cast error|Unexpected character|Converting object|'
  r'[{}<>\[\]]|https?://|localhost|\bnull\b|\bundefined\b',
  caseSensitive: false,
);

String? _clean(String message) {
  final m = message.trim();
  if (m.isEmpty || m.length > 200) return null;
  if (_technical.hasMatch(m)) return null;
  return m;
}
