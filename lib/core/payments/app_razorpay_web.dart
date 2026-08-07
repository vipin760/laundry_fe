import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:razorpay_flutter/razorpay_flutter.dart'
    show PaymentSuccessResponse, PaymentFailureResponse;
import 'package:web/web.dart' as web;

/// JS interop binding for the `Razorpay` constructor injected globally by
/// Checkout.js (https://checkout.razorpay.com/v1/checkout.js).
@JS('Razorpay')
extension type _JSRazorpayCtor._(JSObject _) implements JSObject {
  external factory _JSRazorpayCtor(JSObject options);
  external void open();
  external void on(String event, JSFunction handler);
}

@JS('Razorpay')
external JSAny? get _razorpayGlobalOrNull;

/// Binding for the global `JSON` namespace object — `package:web` doesn't
/// expose it, so it's declared here directly.
@JS('JSON')
external _JSONNamespace get _json;

extension type _JSONNamespace._(JSObject _) implements JSObject {
  external JSAny? parse(String text);
  external String stringify(JSAny? value);
}

Completer<void>? _checkoutJsLoad;

/// Lazily injects Checkout.js the first time a web payment is attempted, so
/// visitors who never pay don't pay the (small) cost of the third-party
/// script on every page load.
Future<void> _ensureCheckoutJsLoaded() {
  if (_razorpayGlobalOrNull != null) return Future.value();
  if (_checkoutJsLoad != null) return _checkoutJsLoad!.future;

  final completer = Completer<void>();
  _checkoutJsLoad = completer;

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = 'https://checkout.razorpay.com/v1/checkout.js'
    ..async = true;

  script.addEventListener(
    'load',
    (() {
      completer.complete();
    }.toJS),
  );
  script.addEventListener(
    'error',
    (() {
      completer.completeError(
        Exception('Could not load the payment gateway. Check your connection and try again.'),
      );
    }.toJS),
  );

  web.document.head!.appendChild(script);
  return completer.future;
}

Map<String, dynamic> _jsObjectToMap(JSAny? value) {
  if (value == null) return const {};
  final jsonString = _json.stringify(value);
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

/// Web backend for [AppRazorpay] — drives Razorpay's hosted Checkout.js SDK
/// via JS interop, since the `razorpay_flutter` plugin has no web
/// implementation (its pubspec only declares android/ios platforms).
class PlatformRazorpay {
  void Function(PaymentSuccessResponse)? _onSuccess;
  void Function(PaymentFailureResponse)? _onError;

  void on(String event, Function handler) {
    switch (event) {
      case 'payment.success':
        _onSuccess = handler as void Function(PaymentSuccessResponse);
      case 'payment.error':
        _onError = handler as void Function(PaymentFailureResponse);
      case 'payment.external_wallet':
        // Checkout.js handles external wallets (e.g. Paytm) fully within its
        // own hosted UI — there's no separate client-side callback to wire up.
        break;
    }
  }

  Future<void> open(Map<String, dynamic> options) async {
    try {
      await _ensureCheckoutJsLoaded();
    } catch (_) {
      _onError?.call(PaymentFailureResponse(
        0,
        'Could not load the payment gateway. Check your connection and try again.',
        null,
      ));
      return;
    }

    // Functions can't survive a JSON round-trip, so build the plain data via
    // JSON.parse(jsonEncode(...)) and attach callbacks afterwards via
    // dart:js_interop_unsafe.
    final jsOptions = _json.parse(jsonEncode(options)) as JSObject;

    jsOptions.setProperty(
      'handler'.toJS,
      ((JSAny response) {
        _onSuccess?.call(PaymentSuccessResponse.fromMap(_jsObjectToMap(response)));
      }).toJS,
    );

    final modal = (_json.parse('{}') as JSObject)
      ..setProperty(
        'ondismiss'.toJS,
        (() {
          _onError?.call(PaymentFailureResponse(2, 'Payment cancelled.', null));
        }).toJS,
      );
    jsOptions.setProperty('modal'.toJS, modal);

    final rzp = _JSRazorpayCtor(jsOptions);

    rzp.on('payment.failed', ((JSAny response) {
      final map = _jsObjectToMap(response);
      final error = map['error'] as Map<String, dynamic>?;
      _onError?.call(PaymentFailureResponse(
        1,
        error?['description'] as String? ?? 'Payment failed. Please try again.',
        error,
      ));
    }).toJS);

    rzp.open();
  }

  void clear() {
    _onSuccess = null;
    _onError = null;
  }
}
