import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../location/models/address_model.dart';
import '../../orders/models/invoice_model.dart';
import '../models/checkout_models.dart';

/// Thrown when checkout fails because the customer's DIRECT_SELECTION branch
/// (Drop at Shop) isn't usable right now — e.g. it just went inactive, hit
/// today's capacity, or has no matching slots. Carries the backend's typed
/// reason [code] (see LocationEligibilityReason in laundry_be) so the caller
/// can show a specific, localized message and send the customer back to
/// branch selection, instead of a generic error.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.code, this.message);
  final String code;
  final String message;

  static const _knownCodes = {
    'LOCATION_INACTIVE',
    'LOCATION_CLOSED_TODAY',
    'LOCATION_CLOSED_THIS_TIME',
    'LOCATION_TEMPORARILY_UNAVAILABLE',
    'DAILY_CAPACITY_REACHED',
    'NO_PICKUP_SLOTS_AVAILABLE',
    'NO_DELIVERY_SLOTS_AVAILABLE',
    'LOCATION_NOT_FOUND',
  };

  /// Builds an instance from a DioException's response body if it carries one
  /// of the known branch-eligibility reason codes; otherwise returns null so
  /// the caller falls back to its normal generic-error handling.
  static LocationUnavailableException? fromDioError(DioException e) {
    final data = e.response?.data;
    if (data is! Map<String, dynamic>) return null;
    final code = data['code'] as String?;
    if (code == null || !_knownCodes.contains(code)) return null;
    final message = data['message'] as String? ?? 'Selected branch is not available right now.';
    return LocationUnavailableException(code, message);
  }
}

class PaymentService {
  final Dio _dio = ApiClient.instance;

  Future<List<CheckoutShop>> getAvailableShops({
    double? latitude,
    double? longitude,
    required String date,
  }) async {
    try {
      final response = await _dio.get('/locations/shops', queryParameters: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'date': date,
      });
      return (response.data as List? ?? [])
          .map((item) => CheckoutShop.fromLocationJson(item as Map<String, dynamic>))
          .where((shop) => shop.isOpen)
          .toList();
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not load nearby shops. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while finding shops.');
    }
  }

  Future<CheckoutOptions?> checkServiceability({
    required CheckoutServiceType serviceType,
    required CheckoutAddress address,
    required String date,
  }) async {
    // Separate the network call from data parsing so that eligibility-reason
    // exceptions propagate instead of being swallowed by the catch-all.
    late final Response<dynamic> response;
    try {
      response = await _dio.get('/locations/serviceability', queryParameters: {
        'serviceType': serviceType.apiValue,
        'latitude': address.latitude,
        'longitude': address.longitude,
        'date': date,
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // 403 / 404 / 5xx — endpoint unavailable, fall back gracefully
      if (status == 403 || status == 404 || status >= 500) return null;
      // Network / timeout errors: surface a clean message
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not check serviceability. Please try again.'));
    }

    if (response.data == null || response.data == '') return null;
    final data = response.data as Map<String, dynamic>;

    // Backend returns { eligible: false, reason: '...', reasonCode: '...' }
    // when no eligible location is found.
    if (data['eligible'] == false) {
      final reason = data['reason'] as String? ??
          'No laundry service is available at your address yet';
      final nearestShop = data['nearestShop'] as Map<String, dynamic>?;

      // When the backend found a shop but it has a temporary issue (daily
      // capacity reached, closed today, etc.) it returns nearestShop so we can
      // still assign a branch. Return partial options — slots come from the
      // standard-time-slots/available endpoint. Backend re-validates at order
      // creation time and will reject if still at capacity.
      if (nearestShop != null) {
        return CheckoutOptions(
          shop: CheckoutShop.fromLocationJson(nearestShop),
          pickupSlots: const [],
          deliverySlots: const [],
          paymentMethods: CheckoutPaymentMethod.values.toList(),
          availabilityWarning: reason,
        );
      }

      // Truly no shop in the area — hard block, show error to user.
      throw Exception(reason);
    }

    return CheckoutOptions.fromServiceabilityJson(data, date);
  }

  /// Raw lat/lng serviceability check — same /locations/serviceability
  /// endpoint and radius logic the pickup-address flow already uses, but
  /// returning a plain yes/no+reason instead of full [CheckoutOptions].
  ///
  /// Used to validate a *return-delivery* ("drop") address at selection time,
  /// so a customer can't pick a saved address outside the shop's delivery
  /// radius and only discover it after the order is placed.
  Future<ServiceabilityCheck> isLocationServiceable({
    required double latitude,
    required double longitude,
    String? date,
  }) async {
    try {
      final response = await _dio.get('/locations/serviceability', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'date': date ?? DateTime.now().toIso8601String().split('T').first,
      });

      if (response.data == null || response.data == '') {
        return const ServiceabilityCheck(
          serviceable: false,
          reason: 'No laundry service is available at this address yet.',
        );
      }
      final data = response.data as Map<String, dynamic>;
      if (data['eligible'] == false) {
        return ServiceabilityCheck(
          serviceable: false,
          reason: data['reason'] as String? ??
              'No laundry service is available at this address yet.',
        );
      }
      return const ServiceabilityCheck(serviceable: true);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // Endpoint unavailable — don't block address selection on an infra
      // hiccup; the backend re-validates again at order-creation time.
      if (status == 403 || status == 404 || status >= 500) {
        return const ServiceabilityCheck(serviceable: true, checkSkipped: true);
      }
      return ServiceabilityCheck(
        serviceable: false,
        reason: _friendlyDioMessage(e, fallback: 'Could not verify this address. Please try again.'),
      );
    } catch (_) {
      return const ServiceabilityCheck(serviceable: true, checkSkipped: true);
    }
  }

  /// Fetches the admin-managed standard time slots for a given date.
  /// Returns pickup and delivery slot lists including the Instant option.
  Future<StandardSlotsResult?> getStandardTimeSlots({required String date}) async {
    try {
      final response = await _dio.get(
        '/standard-time-slots/available',
        queryParameters: {'date': date},
      );
      if (response.data == null) return null;
      final data = response.data as Map<String, dynamic>;
      return StandardSlotsResult.fromJson(data, date);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 403 || status == 404 || status >= 500) return null;
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not load time slots. Please try again.'));
    } catch (_) {
      return null;
    }
  }

  /// Fetches slot/payment options for a specific selected shop.
  /// Uses GET /locations/serviceability with preferredLocationId so the backend
  /// promotes the chosen shop to the top of the candidate list and returns
  /// its specific pickup/delivery slots — matching the same response shape as
  /// checkServiceability, so no separate parser is needed.
  Future<CheckoutOptions?> getCheckoutOptions({
    required CheckoutServiceType serviceType,
    required String selectedShopId,
    required String date,
    double? latitude,
    double? longitude,
  }) async {
    if (latitude == null || longitude == null) return null;
    late final Response<dynamic> response;
    try {
      response = await _dio.get('/locations/serviceability', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'date': date,
        'preferredLocationId': selectedShopId,
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 403 || status == 404 || status >= 500) return null;
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not load slot options. Please try again.'));
    }

    if (response.data == null || response.data == '') return null;
    final data = response.data as Map<String, dynamic>;

    if (data['eligible'] == false) {
      final reason = data['reason'] as String? ??
          'No laundry service is available at your address yet';
      final nearestShop = data['nearestShop'] as Map<String, dynamic>?;
      if (nearestShop != null) {
        return CheckoutOptions(
          shop: CheckoutShop.fromLocationJson(nearestShop),
          pickupSlots: const [],
          deliverySlots: const [],
          paymentMethods: CheckoutPaymentMethod.values.toList(),
          availabilityWarning: reason,
        );
      }
      throw Exception(reason);
    }

    return CheckoutOptions.fromServiceabilityJson(data, date);
  }

  /// Place an order without opening payment (new flow).
  /// Payment is initiated later from My Orders once admin confirms the bill.
  ///
  /// [deliveryType] / [deliveryAddress] control how the *finished* order gets
  /// back to the customer — independent of [checkoutContext]'s pickup details.
  /// Defaults to home delivery when omitted.
  Future<Map<String, dynamic>> placeOrderOnly({
    required CheckoutContext checkoutContext,
    DeliveryType deliveryType = DeliveryType.homeDelivery,
    AddressModel? deliveryAddress,
  }) async {
    try {
      final data = {
        ...checkoutContext.toJson(),
        'deliveryType': deliveryType.apiValue,
        if (deliveryType == DeliveryType.homeDelivery && deliveryAddress != null)
          'deliveryAddress': deliveryAddress.toJson(),
      };
      final response = await _dio.post('/orders/checkout', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final locationError = LocationUnavailableException.fromDioError(e);
      if (locationError != null) throw locationError;
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not place your order. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while placing your order.');
    }
  }

  /// Re-confirm or change self-pickup vs home-delivery before paying.
  /// Only allowed while payment is still pending (backend-enforced).
  Future<void> updateDeliveryDetails({
    required String orderId,
    required DeliveryType deliveryType,
    AddressModel? deliveryAddress,
  }) async {
    try {
      await _dio.patch('/orders/$orderId/delivery-details', data: {
        'deliveryType': deliveryType.apiValue,
        if (deliveryType == DeliveryType.homeDelivery && deliveryAddress != null)
          'deliveryAddress': deliveryAddress.toJson(),
      });
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not update delivery details. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while updating delivery details.');
    }
  }

  /// Initiate payment for an existing order (called from order detail when
  /// order status is PROCESSING/Brewing and bill has been set by admin).
  Future<Map<String, dynamic>> initiatePaymentForOrder({
    required String orderId,
  }) async {
    try {
      final response = await _dio.post('/payments/initiate/$orderId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not initiate payment. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while initiating payment.');
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await _dio.post('/payments/verify', data: {
        'orderId': orderId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Payment verification failed. Please contact support.'));
    } catch (_) {
      throw Exception('Something went wrong during payment verification.');
    }
  }

  /// Fetch a single order for tracking (user's own order).
  Future<Map<String, dynamic>?> getOrderTracking(String orderId) async {
    try {
      final response = await _dio.get('/orders/$orderId');
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) return null;
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not load order details.'));
    } catch (_) {
      return null;
    }
  }

  /// Cancel the user's own order (allowed before itemization).
  Future<void> cancelOrder(String orderId) async {
    try {
      await _dio.post('/orders/$orderId/cancel');
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e,
          fallback: 'Could not cancel the order. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while cancelling the order.');
    }
  }

  /// Confirm delivery with the 4-digit OTP shown by the driver.
  Future<void> confirmDelivery({
    required String orderId,
    required String otp,
  }) async {
    try {
      await _dio.post('/orders/$orderId/confirm-delivery', data: {'otp': otp});
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'OTP confirmation failed. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong confirming delivery.');
    }
  }

  /// Metadata for the "Download Invoice" button — returns null when no
  /// invoice exists yet (order unpaid), so the caller can just hide it
  /// instead of treating a missing invoice as an error.
  Future<InvoiceMetadata?> getInvoiceMetadata(String orderId) async {
    try {
      final response = await _dio.get('/invoices/order/$orderId');
      return InvoiceMetadata.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 404) return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the invoice PDF bytes. Returning raw bytes (rather than
  /// downloading to a local path via `dio.download()`) keeps this working on
  /// web too, where there's no filesystem to download into — saving/sharing
  /// the bytes is handled per-platform by [InvoiceSaver].
  Future<List<int>> downloadInvoiceBytes({required String orderId}) async {
    try {
      final response = await _dio.get<List<int>>(
        '/invoices/order/$orderId/download',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not download the invoice. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while downloading the invoice.');
    }
  }

  Future<void> markPaymentFailed(String orderId) async {
    try {
      await _dio.post('/payments/failed', data: {'orderId': orderId});
    } catch (_) {}
  }

  /// Pay the bill for an existing order using the user's wallet balance.
  /// Returns { success: true, newBalance: double }.
  /// Throws a descriptive [Exception] on insufficient balance or invalid state.
  Future<Map<String, dynamic>> payOrderWithWallet({
    required String orderId,
  }) async {
    try {
      final response = await _dio.post('/wallet/pay-order/$orderId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
        _friendlyDioMessage(e, fallback: 'Could not pay with wallet. Please try again.'),
      );
    } catch (_) {
      throw Exception('Something went wrong while paying with wallet.');
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder({
    required CheckoutContext checkoutContext,
  }) async {
    try {
      final endpoint =
          checkoutContext.paymentMethod == CheckoutPaymentMethod.cashOnDelivery
              ? '/orders/checkout'
              : '/payments/create-order';
      final response = await _dio.post(endpoint, data: checkoutContext.toJson());
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_friendlyDioMessage(e, fallback: 'Could not place your order. Please try again.'));
    } catch (_) {
      throw Exception('Something went wrong while placing your order.');
    }
  }

  // ── Centralised Dio → human message translator ─────────────────────────────

  String _friendlyDioMessage(DioException e, {required String fallback}) {
    // 1. Prefer the server's own message field
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'] ?? data['error'] ?? data['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      // NestJS validation errors return message as a List of strings
      if (msg is List && msg.isNotEmpty) {
        return msg.map((e) => e.toString()).join('. ');
      }
    }
    if (data is String && data.trim().isNotEmpty && data.length < 200) {
      return data.trim();
    }

    // 2. Map HTTP status codes to friendly strings
    switch (e.response?.statusCode) {
      case 400: return 'Invalid request. Please check your details and try again.';
      case 401: return 'Your session has expired. Please log in again.';
      case 403: return 'Access denied. You may not have permission for this action.';
      case 404: return 'The requested resource was not found.';
      case 409: return 'A conflict occurred. Please refresh and try again.';
      case 422: return 'Some details are invalid. Please review and try again.';
      case 429: return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503: return 'Our servers are having trouble right now. Please try again shortly.';
    }

    // 3. Map connection errors
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your internet connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network and try again.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return fallback;
    }
  }
}
