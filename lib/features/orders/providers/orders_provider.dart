import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order_model.dart';

class OrdersState {
  final List<OrderModel> orders;
  final OrdersSummary summary;
  final bool isLoading;
  final String? error;

  OrdersState({
    this.orders = const [],
    this.summary = const OrdersSummary(),
    this.isLoading = false,
    this.error,
  });

  OrdersState copyWith({
    List<OrderModel>? orders,
    OrdersSummary? summary,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrdersNotifier extends Notifier<OrdersState> {
  @override
  OrdersState build() {
    // Gate on auth restoration rather than fetching unconditionally: on
    // web this provider can build before session restore (async) finishes,
    // and fetching before we know the user is logged in sends an
    // unauthenticated request. Watching authProvider re-triggers this once
    // restore completes (or login state actually changes).
    final auth = ref.watch(authProvider);
    if (auth.isInitialized && auth.isAuthenticated) {
      Future.microtask(fetchOrders);
    }
    return OrdersState();
  }

  final _dio = ApiClient.instance;

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _dio.get('/orders/my'),
        _dio.get('/orders/my/summary'),
      ]);

      final List data = results[0].data as List? ?? [];
      final orders = data
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();

      final summary = OrdersSummary.fromJson(
        results[1].data as Map<String, dynamic>? ?? {},
      );

      state = state.copyWith(orders: orders, summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<OrderModel?> fetchOrderDetails(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId');
      return OrderModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> rateOrder(String orderId, int rating, {String? comment}) async {
    try {
      await _dio.post('/orders/$orderId/rate', data: {
        'rating': rating,
        if (comment != null) 'comment': comment,
      });
      // Refresh orders to update rating in local state
      await fetchOrders();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(() {
  return OrdersNotifier();
});
