import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/models/order_model.dart';

/// Outcome of a delivery-completion attempt.
///
/// [countsAsAttempt] is true only when the server actively rejected the OTP,
/// so a flaky network never burns one of the rider's limited attempts.
class CompleteDeliveryResult {
  const CompleteDeliveryResult({
    required this.success,
    this.countsAsAttempt = false,
    this.message,
  });

  final bool success;
  final bool countsAsAttempt;
  final String? message;
}

/// Client-side throttle for delivery-OTP entry.
///
/// This is defence-in-depth only — the backend remains authoritative for OTP
/// validation, rate limiting and lockout. It lives on the notifier (rather
/// than in the sheet's widget state) so that dismissing and reopening the
/// sheet does not hand the user a fresh set of attempts.
class OtpThrottleState {
  const OtpThrottleState({this.failedAttempts = 0, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  static const maxAttempts = 5;
  static const lockoutDuration = Duration(minutes: 1);

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  Duration get remainingLockout {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  int get attemptsLeft {
    final left = maxAttempts - failedAttempts;
    return left < 0 ? 0 : left;
  }
}

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

  final _otpThrottle = <String, OtpThrottleState>{};

  /// Current throttle for [orderId]. Once a lockout has elapsed the counter
  /// starts over, so an expired lockout grants a fresh set of attempts rather
  /// than leaving the rider one failure away from being locked again.
  OtpThrottleState otpThrottleFor(String orderId) {
    final stored = _otpThrottle[orderId];
    if (stored == null) return const OtpThrottleState();
    if (stored.lockedUntil != null && !stored.isLocked) {
      _otpThrottle.remove(orderId);
      return const OtpThrottleState();
    }
    return stored;
  }

  /// Confirms handover by submitting the OTP the customer received after
  /// payment. The OTP itself is validated server-side — this only records
  /// rejected attempts locally so the UI can throttle repeated guesses.
  Future<CompleteDeliveryResult> completeDelivery(
    String orderId,
    String otp,
  ) async {
    final throttle = otpThrottleFor(orderId);
    if (throttle.isLocked) {
      return CompleteDeliveryResult(
        success: false,
        message: 'Too many incorrect attempts. Try again in '
            '${throttle.remainingLockout.inSeconds}s.',
      );
    }

    try {
      await _dio.post(
        '/orders/$orderId/complete-delivery',
        data: {'otp': otp.trim()},
      );
      _otpThrottle.remove(orderId);
      await fetchAssigned();
      return const CompleteDeliveryResult(success: true);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final message = e.response?.data is Map
          ? (e.response!.data['message']?.toString())
          : null;

      // 429 means the backend is already throttling — surface its message and
      // don't also burn a local attempt for it.
      if (status == 429) {
        return CompleteDeliveryResult(
          success: false,
          message: message ??
              'Too many attempts. Please wait a moment and try again.',
        );
      }

      // A response in the 4xx range is the server actively rejecting the OTP
      // (or the request); anything else (timeout, no connection, 5xx) never
      // reached a verification decision, so it must not count as an attempt.
      final isRejection = status >= 400 && status < 500;
      if (isRejection) _recordFailedOtpAttempt(orderId);

      return CompleteDeliveryResult(
        success: false,
        countsAsAttempt: isRejection,
        message: message ?? 'Could not verify the OTP. Please try again.',
      );
    } catch (_) {
      return const CompleteDeliveryResult(
        success: false,
        message: 'Could not verify the OTP. Please try again.',
      );
    }
  }

  void _recordFailedOtpAttempt(String orderId) {
    final current = otpThrottleFor(orderId);
    final failed = current.failedAttempts + 1;
    _otpThrottle[orderId] = OtpThrottleState(
      failedAttempts: failed,
      lockedUntil: failed >= OtpThrottleState.maxAttempts
          ? DateTime.now().add(OtpThrottleState.lockoutDuration)
          : null,
    );
  }
}

final deliveryOrdersProvider =
    NotifierProvider<DeliveryOrdersNotifier, DeliveryOrdersState>(() {
  return DeliveryOrdersNotifier();
});
