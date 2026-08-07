import 'package:razorpay_flutter/razorpay_flutter.dart' as rzp;

/// Android/iOS backend for [AppRazorpay] — thin pass-through to the native
/// `razorpay_flutter` plugin.
class PlatformRazorpay {
  final rzp.Razorpay _razorpay = rzp.Razorpay();

  void on(String event, Function handler) => _razorpay.on(event, handler);

  void open(Map<String, dynamic> options) => _razorpay.open(options);

  void clear() => _razorpay.clear();
}
