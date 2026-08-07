import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/coupon_model.dart';

/// Data-access layer for the customer-facing coupon backend endpoints
/// (`/customer/coupon/...`). Coupons are private/assigned — every route
/// requires the normal auth Bearer token, which [ApiClient.instance]
/// already attaches.
class CouponService {
  final Dio _dio;

  CouponService() : _dio = ApiClient.instance;

  /// GET /customer/coupon/my-coupons
  /// Coupons actually assigned to and currently usable by this user.
  Future<List<Coupon>> getMyCoupons() async {
    try {
      final response = await _dio.get('/customer/coupon/my-coupons');
      final data = response.data as Map<String, dynamic>;
      final coupons = data['coupons'] as List<dynamic>? ?? [];
      return coupons
          .map((item) => Coupon.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not load your coupons. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while loading your coupons.');
    }
  }

  /// POST /customer/coupon/validate
  /// Preview-only: checks whether [couponCode] is usable for [orderAmount].
  Future<CouponDiscount> validateCoupon(String couponCode, double orderAmount) async {
    try {
      final response = await _dio.post(
        '/customer/coupon/validate',
        data: {
          'couponCode': couponCode,
          'orderAmount': orderAmount,
        },
      );
      return CouponDiscount.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not validate this coupon. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while validating this coupon.');
    }
  }

  /// POST /customer/coupon/apply-to-order
  /// Persists [couponCode] onto the existing order [orderId] server-side,
  /// reducing its payable amount. Whatever payment path runs next
  /// automatically charges the discounted amount. Redemption itself
  /// happens automatically, server-side, the moment payment succeeds —
  /// there is nothing further for the client to record.
  Future<CouponDiscount> applyToOrder(String orderId, String couponCode) async {
    try {
      final response = await _dio.post(
        '/customer/coupon/apply-to-order',
        data: {
          'orderId': orderId,
          'couponCode': couponCode,
        },
      );
      return CouponDiscount.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not apply this coupon. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while applying this coupon.');
    }
  }

  /// POST /customer/coupon/remove-from-order
  /// Undoes apply-to-order. Only works before payment.
  Future<void> removeFromOrder(String orderId) async {
    try {
      await _dio.post(
        '/customer/coupon/remove-from-order',
        data: {'orderId': orderId},
      );
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not remove this coupon. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while removing this coupon.');
    }
  }

  // ── Dio → human message translator ──────────────────────────────────────
  // Mirrors the convention used elsewhere in the app (see
  // PaymentService._friendlyDioMessage): prefer the backend's own
  // `message` field verbatim (the coupon backend's error strings, e.g.
  // "Coupon has expired.", are already user-facing), then fall back to a
  // generic message per status code / connection error.
  String _friendlyDioMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'] ?? data['error'] ?? data['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      if (msg is List && msg.isNotEmpty) {
        return msg.map((e) => e.toString()).join('. ');
      }
    }
    if (data is String && data.trim().isNotEmpty && data.length < 200) {
      return data.trim();
    }

    switch (e.response?.statusCode) {
      case 400: return 'Invalid request. Please check your details and try again.';
      case 401: return 'Your session has expired. Please log in again.';
      case 403: return 'This coupon is not available for your account.';
      case 404: return 'Coupon not found';
      case 409: return 'A conflict occurred. Please refresh and try again.';
      case 422: return 'Some details are invalid. Please review and try again.';
      case 429: return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503: return 'Our servers are having trouble right now. Please try again shortly.';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your internet connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network and try again.';
      default:
        return fallback;
    }
  }
}
