import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';

/// State for the delivery partner's assigned orders.
class DeliveryOrdersState {
  final List<OrderModel> active;
  final List<OrderModel> completed;
  final bool isLoading;
  final String? error;

  DeliveryOrdersState({
    this.active = const [],
    this.completed = const [],
    this.isLoading = false,
    this.error,
  });

  DeliveryOrdersState copyWith({
    List<OrderModel>? active,
    List<OrderModel>? completed,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DeliveryOrdersState(
      active: active ?? this.active,
      completed: completed ?? this.completed,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeliveryOrdersNotifier extends Notifier<DeliveryOrdersState> {
  @override
  DeliveryOrdersState build() {
    // Gate on auth restoration rather than fetching unconditionally: on
    // web this provider can build before session restore (async) finishes,
    // and fetching before we know the user is logged in sends an
    // unauthenticated request. Watching authProvider re-triggers this once
    // restore completes (or login state actually changes).
    final auth = ref.watch(authProvider);
    final willFetch = auth.isInitialized && auth.isAuthenticated;
    if (willFetch) {
      Future.microtask(fetchAssigned);
    }
    // isLoading only makes sense while a fetch is actually pending — for a
    // logged-out (or not-yet-restored) user there is no in-flight request
    // to wait on, so it must not be left stuck true.
    return DeliveryOrdersState(isLoading: willFetch);
  }

  final _dio = ApiClient.instance;

  Future<void> fetchAssigned() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get('/orders/delivery/assigned');
      final data = response.data as Map<String, dynamic>? ?? {};

      List<OrderModel> parse(dynamic list) => (list as List? ?? [])
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        active: parse(data['active']),
        completed: parse(data['completed']),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your deliveries. Pull down to retry.',
      );
    }
  }

  /// Creates (or reuses) the Razorpay payment link / QR for this order so the
  /// customer can pay at the door. Returns the link + expiry, or an error.
  Future<({String? link, DateTime? expiresAt, String? error})> startPayment(
      String orderId) async {
    try {
      final r = await _dio.post('/payments/qr/orders/$orderId');
      final qr = (r.data is Map ? r.data['qr'] : null) as Map?;
      final link = qr?['upiUri'] as String?;
      if (link == null || link.isEmpty) {
        return (link: null, expiresAt: null, error: 'Could not create the payment link.');
      }
      final exp = DateTime.tryParse('${qr?['expiresAt']}')?.toLocal();
      return (link: link, expiresAt: exp, error: null);
    } on DioException catch (e) {
      final m = e.response?.data is Map ? e.response!.data['message']?.toString() : null;
      return (link: null, expiresAt: null, error: m ?? 'Could not create the payment link.');
    } catch (_) {
      return (link: null, expiresAt: null, error: 'Could not create the payment link.');
    }
  }

  /// Server-verified paid check (the backend reconciles with Razorpay on read).
  /// null = couldn't check; never treated as paid.
  Future<bool?> isOrderPaid(String orderId) async {
    try {
      final r = await _dio.get('/payments/qr/orders/$orderId');
      final order = r.data is Map ? r.data['order'] : null;
      if (order is! Map) return null;
      return order['paymentStatus'] == 'COMPLETED';
    } catch (_) {
      return null;
    }
  }

  /// Confirms handover by submitting the OTP the customer received after
  /// payment. Returns null on success, or an error message to display.
  Future<String?> completeDelivery(String orderId, String otp) async {
    try {
      await _dio.post(
        '/orders/$orderId/complete-delivery',
        data: {'otp': otp.trim()},
      );
      await fetchAssigned();
      return null;
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response!.data['message']?.toString())
          : null;
      return message ?? 'Could not verify the OTP. Please try again.';
    } catch (_) {
      return 'Could not verify the OTP. Please try again.';
    }
  }
}

final deliveryOrdersProvider =
    NotifierProvider<DeliveryOrdersNotifier, DeliveryOrdersState>(() {
  return DeliveryOrdersNotifier();
});
