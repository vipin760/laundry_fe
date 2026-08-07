/// Discount type as defined by the coupon backend.
enum CouponDiscountType { fixed, percentage }

CouponDiscountType _parseDiscountType(dynamic value) {
  switch (value?.toString()) {
    case 'percentage':
      return CouponDiscountType.percentage;
    case 'fixed':
    default:
      return CouponDiscountType.fixed;
  }
}

/// A coupon assigned to (and currently usable by) the logged-in user.
/// Matches the shape returned by GET /customer/coupon/my-coupons.
class Coupon {
  final String couponId;
  final String couponCode;
  final String couponName;
  final String? description;
  final CouponDiscountType discountType;
  final double discountValue;
  final double? maximumDiscount;
  final double minimumOrderAmount;
  final DateTime expiryDate;
  final int remainingUses;

  Coupon({
    required this.couponId,
    required this.couponCode,
    required this.couponName,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maximumDiscount,
    required this.minimumOrderAmount,
    required this.expiryDate,
    required this.remainingUses,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      couponId: json['couponId'] as String,
      couponCode: json['couponCode'] as String,
      couponName: json['couponName'] as String,
      description: json['description'] as String?,
      discountType: _parseDiscountType(json['discountType']),
      discountValue: (json['discountValue'] as num).toDouble(),
      maximumDiscount: json['maximumDiscount'] != null
          ? (json['maximumDiscount'] as num).toDouble()
          : null,
      minimumOrderAmount: (json['minimumOrderAmount'] as num?)?.toDouble() ?? 0,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      remainingUses: (json['remainingUses'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'couponId': couponId,
      'couponCode': couponCode,
      'couponName': couponName,
      'description': description,
      'discountType': discountType == CouponDiscountType.percentage
          ? 'percentage'
          : 'fixed',
      'discountValue': discountValue,
      'maximumDiscount': maximumDiscount,
      'minimumOrderAmount': minimumOrderAmount,
      'expiryDate': expiryDate.toIso8601String(),
      'remainingUses': remainingUses,
    };
  }
}

/// Result of validating / applying / applying-to-order a coupon.
/// Matches the shared response shape of validate, apply and
/// apply-to-order on the customer coupon endpoints.
class CouponDiscount {
  final String couponId;
  final String couponCode;
  final String couponName;
  final double originalAmount;
  final double discountAmount;
  final double finalAmount;

  CouponDiscount({
    required this.couponId,
    required this.couponCode,
    required this.couponName,
    required this.originalAmount,
    required this.discountAmount,
    required this.finalAmount,
  });

  factory CouponDiscount.fromJson(Map<String, dynamic> json) {
    return CouponDiscount(
      couponId: json['couponId'] as String,
      couponCode: json['couponCode'] as String,
      couponName: json['couponName'] as String? ?? json['couponCode'] as String,
      originalAmount: (json['originalAmount'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num).toDouble(),
      finalAmount: (json['finalAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'couponId': couponId,
      'couponCode': couponCode,
      'couponName': couponName,
      'originalAmount': originalAmount,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
    };
  }
}
