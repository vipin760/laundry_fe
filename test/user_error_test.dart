import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laudry_app/core/utils/user_error.dart';

const _fb = 'Could not download the invoice. Please try again.';

DioException _dio({
  DioExceptionType type = DioExceptionType.badResponse,
  int? status,
  Object? data,
}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: type,
    response: status == null ? null : Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('userErrorMessage', () {
    test('hides the iOS share-sheet PlatformException from the invoice bug', () {
      final e = PlatformException(
        code: 'error',
        message: 'sharePositionOrigin: argument must be set, {{0, 0}, {0, 0}} must be non-zero',
      );
      expect(userErrorMessage(e, fallback: _fb), _fb);
    });

    test('keeps friendly messages our services throw', () {
      expect(userErrorMessage(Exception('Coupon has expired.'), fallback: _fb), 'Coupon has expired.');
    });

    test('hides technical text wrapped in a plain Exception', () {
      expect(userErrorMessage(Exception("type 'Null' is not a subtype of type 'String'"), fallback: _fb), _fb);
      expect(userErrorMessage(Exception('DioException [bad response]: status code 500'), fallback: _fb), _fb);
    });

    test('hides runtime errors', () {
      expect(userErrorMessage(TypeError(), fallback: _fb), _fb);
      expect(userErrorMessage(const FormatException('Unexpected character'), fallback: _fb), _fb);
      expect(userErrorMessage(StateError('Bad state: no element'), fallback: _fb), _fb);
    });

    test('uses the server message when it is user copy', () {
      expect(userErrorMessage(_dio(status: 400, data: {'message': 'Order already paid'}), fallback: _fb),
          'Order already paid');
      expect(userErrorMessage(_dio(status: 400, data: {'message': ['Name is required', 'Pincode is invalid']}), fallback: _fb),
          'Name is required. Pincode is invalid');
    });

    test('never shows an HTML error page or JSON', () {
      expect(userErrorMessage(_dio(status: 502, data: '<html><body>Bad Gateway</body></html>'), fallback: _fb),
          kServerBusyMessage);
      expect(userErrorMessage(_dio(status: 400, data: {'message': '{"code":"E_1"}'}), fallback: _fb), _fb);
    });

    test('maps network problems', () {
      expect(userErrorMessage(_dio(type: DioExceptionType.connectionError), fallback: _fb), kNoInternetMessage);
      expect(userErrorMessage(_dio(type: DioExceptionType.receiveTimeout), fallback: _fb), kSlowNetworkMessage);
      expect(userErrorMessage(TimeoutException('t'), fallback: _fb), kSlowNetworkMessage);
      expect(userErrorMessage(Exception('SocketException: Failed host lookup'), fallback: _fb), kNoInternetMessage);
    });
  });

  group('paymentFailureMessage', () {
    test('cancelled and network codes', () {
      expect(paymentFailureMessage(2, 'anything'), 'Payment cancelled.');
      expect(paymentFailureMessage(0, null), contains('network'));
    });

    test('extracts the description from Razorpay JSON', () {
      const raw = '{"error":{"code":"BAD_REQUEST_ERROR","description":"Your card was declined.","source":"bank"}}';
      expect(paymentFailureMessage(1, raw), 'Your card was declined.');
    });

    test('falls back for junk', () {
      expect(paymentFailureMessage(100, 'undefined'), 'Payment failed. Please try again.');
      expect(paymentFailureMessage(100, '{not json'), 'Payment failed. Please try again.');
      expect(paymentFailureMessage(100, null), 'Payment failed. Please try again.');
    });
  });
}
