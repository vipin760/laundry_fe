import '../../checkout/models/checkout_models.dart' show DeliveryType;
import '../../location/models/address_model.dart';

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
}

enum PaymentStatus {
  pending,
  completed,
  failed,
}

class OrderItemModel {
  final String serviceId;
  final String serviceName;
  final String? icon;
  final int quantity;
  final double price;

  OrderItemModel({
    required this.serviceId,
    required this.serviceName,
    this.icon,
    required this.quantity,
    required this.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      serviceId: json['serviceId'] ?? '',
      serviceName: json['serviceName'] ?? '',
      icon: json['icon'],
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Photo attached to an order by admin.
/// - damage/findings: evidence of pre-existing damage taken at pickup
/// - weighing: scale reading uploaded with the bill (kg proof)
class OrderPhotoModel {
  final String id;
  final String url;
  final String? note;
  final DateTime? uploadedAt;

  OrderPhotoModel({
    required this.id,
    required this.url,
    this.note,
    this.uploadedAt,
  });

  factory OrderPhotoModel.fromJson(Map<String, dynamic> json) {
    return OrderPhotoModel(
      id: json['_id'] ?? '',
      url: json['url'] ?? '',
      note: (json['note'] as String?)?.trim().isEmpty == true
          ? null
          : json['note'] as String?,
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'])
          : null,
    );
  }
}

/// Customer contact details attached to an order for the delivery-partner
/// view only — server sends exactly name/phone/address, nothing else.
class DeliveryCustomerContact {
  final String? name;
  final String? phone;
  final String? address;

  DeliveryCustomerContact({this.name, this.phone, this.address});

  factory DeliveryCustomerContact.fromJson(Map<String, dynamic> json) {
    return DeliveryCustomerContact(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }
}

/// Building reception/security-desk details the customer provided at
/// checkout — only present when the order's pickup type is HOME_RECEPTION.
class DeliveryReceptionDetails {
  final String? receptionName;
  final String? flatVillaNumber;
  final String? securityInstructions;
  final String? pickupNotes;

  DeliveryReceptionDetails({
    this.receptionName,
    this.flatVillaNumber,
    this.securityInstructions,
    this.pickupNotes,
  });

  factory DeliveryReceptionDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryReceptionDetails(
      receptionName: json['receptionName'] as String?,
      flatVillaNumber: json['flatVillaNumber'] as String?,
      securityInstructions: json['securityInstructions'] as String?,
      pickupNotes: json['pickupNotes'] as String?,
    );
  }
}

class OrderModel {
  final String id;
  final String? orderNumber;
  final List<OrderItemModel> items;
  final double totalAmount;
  final double? billAmount;

  /// billAmount before the first-order discount was subtracted — only set
  /// when [firstOrderDiscountAmount] > 0. Used to show a strikethrough price.
  final double? originalBillAmount;

  /// Amount knocked off the bill because this is the customer's first order.
  /// 0/null when no first-order discount applies.
  final double? firstOrderDiscountAmount;

  /// Coupon code applied at checkout, if any.
  final String? couponCode;

  /// ₹ discount granted by the coupon, already subtracted from the bill.
  final double? couponDiscountAmount;

  // ── Pricing engine breakdown (additive — absent on orders placed before
  // this rolled out; UI falls back to the plain bill-only display then) ────
  final double? taxAmount;
  final double? deliveryFee;
  final double? platformFee;
  final double? convenienceFee;
  final double? packagingFee;
  /// True once an admin has overridden the engine-calculated bill amount.
  final bool isManuallyAdjusted;

  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? address;

  /// Customer contact details — attached server-side for delivery-partner
  /// order views only (name/phone/address, nothing else).
  final DeliveryCustomerContact? customer;

  /// Building reception/security-desk details — only set when this order's
  /// pickup type is HOME_RECEPTION.
  final DeliveryReceptionDetails? receptionDetails;

  /// How the finished order gets back to the customer. Defaults to home delivery.
  final DeliveryType deliveryType;

  /// Return-delivery address — only set/used when [deliveryType] is homeDelivery.
  final AddressModel? deliveryAddress;

  /// Shop name — used for self-pickup "collect from {shopName}" messaging.
  final String? shopName;

  final DateTime createdAt;
  final DateTime? pickupDate;
  final String? pickupSlot;
  final String? deliverySlot;

  /// Scheduled orders: delivery is the same slot as pickup, next day.
  final DateTime? deliveryDate;

  /// Pickup time set by admin during itemization (e.g. "10:30 AM").
  final String? pickupTime;

  // Tracking fields
  final String? driverName;
  final String? driverPhone;
  final double? weightKg;
  final int? itemCount;

  /// Secure 4-digit delivery OTP — generated after payment is verified.
  /// Visible only to the user who owns this order.
  final String? deliveryOtp;

  // Out-for-delivery live tracking
  final int? etaMinutes;
  final double? driverDistanceKm;

  /// Next milestone the order is working toward — 'PICKUP', 'DELIVERY', or
  /// 'COMPLETION' (instant orders) — null once completed/cancelled.
  final String? etaMilestone;

  /// Expected time for [etaMilestone]. Server-computed from the pickup slot
  /// or committed delivery date; render as a friendly "expected by" time,
  /// never as an overdue/alarm state — that framing is admin-only.
  final DateTime? etaDeadline;

  // Post-delivery rating
  final int? rating;
  final String? ratingComment;

  /// Findings/damage evidence photos taken by admin at pickup.
  final List<OrderPhotoModel> damagePhotos;

  /// Weighing scale / bill proof photos.
  final List<OrderPhotoModel> weighingPhotos;

  OrderModel({
    required this.id,
    this.orderNumber,
    required this.items,
    required this.totalAmount,
    this.billAmount,
    this.originalBillAmount,
    this.firstOrderDiscountAmount,
    this.couponCode,
    this.couponDiscountAmount,
    this.taxAmount,
    this.deliveryFee,
    this.platformFee,
    this.convenienceFee,
    this.packagingFee,
    this.isManuallyAdjusted = false,
    required this.status,
    required this.paymentStatus,
    this.address,
    this.customer,
    this.receptionDetails,
    this.deliveryType = DeliveryType.homeDelivery,
    this.deliveryAddress,
    this.shopName,
    required this.createdAt,
    this.pickupDate,
    this.pickupSlot,
    this.deliverySlot,
    this.deliveryDate,
    this.pickupTime,
    this.driverName,
    this.driverPhone,
    this.weightKg,
    this.itemCount,
    this.deliveryOtp,
    this.etaMinutes,
    this.driverDistanceKm,
    this.etaMilestone,
    this.etaDeadline,
    this.rating,
    this.ratingComment,
    this.damagePhotos = const [],
    this.weighingPhotos = const [],
  });

  /// Display label — e.g. "LB20394" or last-6 of the MongoDB id.
  String get displayNumber =>
      orderNumber ?? id.substring(id.length > 6 ? id.length - 6 : 0).toUpperCase();

  /// Effective amount after itemization (falls back to original total).
  double get effectiveAmount => billAmount ?? totalAmount;

  /// True when a first-order discount was applied to this bill.
  bool get hasFirstOrderDiscount =>
      (firstOrderDiscountAmount ?? 0) > 0 && originalBillAmount != null;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'] ?? '',
      orderNumber: json['orderNumber'] as String?,
      items: (json['items'] as List?)
              ?.map((i) => OrderItemModel.fromJson(i))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      billAmount: (json['billAmount'] as num?)?.toDouble(),
      originalBillAmount: (json['originalBillAmount'] as num?)?.toDouble(),
      firstOrderDiscountAmount:
          (json['firstOrderDiscountAmount'] as num?)?.toDouble(),
      couponCode: json['couponCode'] as String?,
      couponDiscountAmount: (json['couponDiscountAmount'] as num?)?.toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      platformFee: (json['platformFee'] as num?)?.toDouble(),
      convenienceFee: (json['convenienceFee'] as num?)?.toDouble(),
      packagingFee: (json['packagingFee'] as num?)?.toDouble(),
      isManuallyAdjusted: json['isManuallyAdjusted'] as bool? ?? false,
      status: _parseOrderStatus(json['status']),
      paymentStatus: _parsePaymentStatus(json['paymentStatus']),
      address: json['address'],
      customer: json['customer'] != null
          ? DeliveryCustomerContact.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      receptionDetails: json['receptionDetails'] != null
          ? DeliveryReceptionDetails.fromJson(json['receptionDetails'] as Map<String, dynamic>)
          : null,
      deliveryType: _parseDeliveryType(json['deliveryType']),
      deliveryAddress: json['deliveryAddress'] != null
          ? AddressModel.fromJson(json['deliveryAddress'] as Map<String, dynamic>)
          : null,
      shopName: (json['locationSnapshot'] as Map<String, dynamic>?)?['shopName'] as String?,
      createdAt: DateTime.parse(json['createdAt']),
      pickupDate: json['pickupDate'] != null
          ? DateTime.tryParse(json['pickupDate'])
          : null,
      pickupSlot: json['pickupSlot'],
      deliverySlot: json['deliverySlot'],
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.tryParse(json['deliveryDate'])
          : null,
      pickupTime: json['pickupTime'] as String?,
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      itemCount: json['itemCount'] as int?,
      deliveryOtp: json['deliveryOtp'] as String?,
      etaMinutes: json['etaMinutes'] as int?,
      driverDistanceKm: (json['driverDistanceKm'] as num?)?.toDouble(),
      etaMilestone: json['etaMilestone'] as String?,
      etaDeadline: json['etaDeadline'] != null
          ? DateTime.tryParse(json['etaDeadline'])
          : null,
      rating: json['rating'] as int?,
      ratingComment: json['ratingComment'],
      damagePhotos: (json['damagePhotos'] as List?)
              ?.map((p) => OrderPhotoModel.fromJson(p))
              .toList() ??
          const [],
      weighingPhotos: (json['weighingPhotos'] as List?)
              ?.map((p) => OrderPhotoModel.fromJson(p))
              .toList() ??
          const [],
    );
  }

  static OrderStatus _parseOrderStatus(String? status) {
    switch (status) {
      case 'ORDER_PLACED':     return OrderStatus.orderPlaced;
      case 'PICKUP_ASSIGNED':  return OrderStatus.pickupAssigned;
      case 'ITEMIZED':         return OrderStatus.itemized;
      case 'PROCESSING':       return OrderStatus.brewing;
      case 'OUT_FOR_DELIVERY': return OrderStatus.outForDelivery;
      case 'READY_FOR_PICKUP': return OrderStatus.readyForPickup;
      case 'COMPLETED':        return OrderStatus.completed;
      case 'CANCELLED':        return OrderStatus.cancelled;
      default:                 return OrderStatus.orderPlaced;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'PENDING':   return PaymentStatus.pending;
      case 'COMPLETED': return PaymentStatus.completed;
      case 'FAILED':    return PaymentStatus.failed;
      default:          return PaymentStatus.pending;
    }
  }

  static DeliveryType _parseDeliveryType(String? type) {
    switch (type) {
      case 'SELF_PICKUP': return DeliveryType.selfPickup;
      default:             return DeliveryType.homeDelivery;
    }
  }
}

class OrdersSummary {
  final int activeCount;
  final int completedCount;
  final int cancelledCount;
  final double totalSaved;

  const OrdersSummary({
    this.activeCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.totalSaved = 0,
  });

  factory OrdersSummary.fromJson(Map<String, dynamic> json) {
    return OrdersSummary(
      activeCount: json['activeCount'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      cancelledCount: json['cancelledCount'] as int? ?? 0,
      totalSaved: (json['totalSaved'] as num?)?.toDouble() ?? 0,
    );
  }
}
