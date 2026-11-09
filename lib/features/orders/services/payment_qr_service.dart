import '../../../core/api/api_client.dart';

/// Server-verified payment state for an order that may be paid at the door
/// via a delivery-time UPI QR. Read-only for customers: the customer app can
/// *ask* the server what happened, but nothing here can mark an order paid.
class PaymentQrService {
  /// Asks the backend to reconcile this order's QR payment against Razorpay
  /// (covers a delayed/missed webhook) and returns whether the order is now
  /// paid. Returns null if the check itself failed — callers should treat
  /// that as "unknown", never as "unpaid".
  Future<bool?> syncAndCheckPaid(String orderId) async {
    try {
      final response = await ApiClient.instance.get('/payments/qr/orders/$orderId');
      final data = response.data;
      if (data is! Map) return null;
      final order = data['order'];
      if (order is! Map) return null;
      return order['paymentStatus'] == 'COMPLETED';
    } catch (_) {
      return null;
    }
  }

  /// Asks the server for a fresh delivery OTP (the old one expired / locked).
  /// Returns null on success, otherwise a user-presentable error message.
  Future<String?> requestNewDeliveryOtp(String orderId) async {
    try {
      await ApiClient.instance.post('/orders/$orderId/delivery-otp/resend');
      return null;
    } catch (e) {
      try {
        final data = (e as dynamic).response?.data;
        final msg = data is Map ? data['message'] : null;
        if (msg is String && msg.isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      } catch (_) {}
      return 'Could not get a new OTP. Please try again.';
    }
  }
}
