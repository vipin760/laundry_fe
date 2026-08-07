// ignore_for_file: constant_identifier_names
// Matches the naming used by package:razorpay_flutter's own Razorpay class,
// so this stays a drop-in replacement at call sites.
import 'app_razorpay_mobile.dart'
    if (dart.library.js_interop) 'app_razorpay_web.dart' as platform;

export 'package:razorpay_flutter/razorpay_flutter.dart'
    show PaymentSuccessResponse, PaymentFailureResponse, ExternalWalletResponse;

/// Cross-platform Razorpay checkout.
///
/// The `razorpay_flutter` plugin only ships Android/iOS platform channel
/// implementations — invoking it on Flutter Web throws a
/// `MissingPluginException` because there is no web plugin registered. This
/// class hides that split: it wraps the native plugin on mobile and drives
/// Razorpay's hosted Checkout.js SDK via JS interop on web, behind one API
/// so screens never need to branch on platform.
class AppRazorpay {
  static const EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const EVENT_PAYMENT_ERROR = 'payment.error';
  static const EVENT_EXTERNAL_WALLET = 'payment.external_wallet';

  final platform.PlatformRazorpay _impl = platform.PlatformRazorpay();

  void on(String event, Function handler) => _impl.on(event, handler);

  void open(Map<String, dynamic> options) => _impl.open(options);

  void clear() => _impl.clear();
}
