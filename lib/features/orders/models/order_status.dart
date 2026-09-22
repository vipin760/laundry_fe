import 'package:flutter/foundation.dart';

enum OrderStatus {
  orderPlaced,
  pickupAssigned,
  itemized,

  /// PROCESSING on backend — clothes being cleaned, user pays at this stage
  brewing,

  /// HOME_DELIVERY orders only
  outForDelivery,

  /// SELF_PICKUP orders only — ready to collect at the shop
  readyForPickup,
  completed,
  cancelled,

  /// The backend sent a status this build doesn't recognise.
  ///
  /// Kept distinct from [orderPlaced] deliberately: silently showing an
  /// unknown status as "just placed" contradicts whatever else the order
  /// already shows (a bill, an OTP, a completed payment) and hides the fact
  /// that the app is out of date with the backend.
  unknown,
}

/// Single source of truth for interpreting the backend's order status strings.
///
/// Every screen goes through here so a status added server-side behaves
/// consistently (and visibly) everywhere instead of each screen inventing its
/// own fallback.
class OrderStatusMapper {
  const OrderStatusMapper._();

  static const Map<String, OrderStatus> _byApiKey = {
    'ORDER_PLACED': OrderStatus.orderPlaced,
    'PICKUP_ASSIGNED': OrderStatus.pickupAssigned,
    'ITEMIZED': OrderStatus.itemized,
    'PROCESSING': OrderStatus.brewing,
    'OUT_FOR_DELIVERY': OrderStatus.outForDelivery,
    'READY_FOR_PICKUP': OrderStatus.readyForPickup,
    'COMPLETED': OrderStatus.completed,
    'CANCELLED': OrderStatus.cancelled,
  };

  /// Unknown values already reported, so a 30-second poll doesn't spam logs.
  static final Set<String> _reportedUnknown = <String>{};

  static OrderStatus fromApi(Object? raw) {
    if (raw is! String || raw.isEmpty) return OrderStatus.unknown;
    final match = _byApiKey[raw];
    if (match != null) return match;

    if (_reportedUnknown.add(raw)) {
      debugPrint('[OrderStatus] unrecognised status from backend: "$raw"');
    }
    return OrderStatus.unknown;
  }

  static String? apiKey(OrderStatus status) {
    for (final entry in _byApiKey.entries) {
      if (entry.value == status) return entry.key;
    }
    return null;
  }

  /// Customer-facing label. [unknown] reads as a neutral "in progress" rather
  /// than claiming a specific stage the app can't actually verify.
  static String label(OrderStatus status) {
    switch (status) {
      case OrderStatus.orderPlaced:
        return 'Confirmed';
      case OrderStatus.pickupAssigned:
        return 'Pickup Assigned';
      case OrderStatus.itemized:
        return 'Itemized';
      case OrderStatus.brewing:
        return 'Brewing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.readyForPickup:
        return 'Ready for Delivery';
      case OrderStatus.completed:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.unknown:
        return 'In Progress';
    }
  }

  /// 0-based position on the 5-step tracking timeline, or null for statuses
  /// that have no place on it (cancelled, or a status we don't recognise).
  static int? timelineIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.orderPlaced:
        return 0;
      case OrderStatus.pickupAssigned:
        return 1;
      case OrderStatus.itemized:
        return 2;
      case OrderStatus.brewing:
        return 3;
      case OrderStatus.outForDelivery:
      case OrderStatus.readyForPickup:
      case OrderStatus.completed:
        return 4;
      case OrderStatus.cancelled:
      case OrderStatus.unknown:
        return null;
    }
  }
}
