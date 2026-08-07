// Referral feature data models.
//
// Mirrors the backend Refer & Earn API contract (laundry_be/src/referrals).
// Kept as plain immutable value objects with fromJson factories, matching the
// existing app convention (see wallet_transaction_model.dart).

/// Lifecycle status of a single referral (must match backend ReferralStatus).
enum ReferralStatus {
  pending,
  registered,
  firstOrderCompleted,
  paymentCompleted,
  rewardReleased,
  expired,
  rejected,
  unknown;

  static ReferralStatus fromApi(String? v) {
    switch (v) {
      case 'PENDING':
        return ReferralStatus.pending;
      case 'REGISTERED':
        return ReferralStatus.registered;
      case 'FIRST_ORDER_COMPLETED':
        return ReferralStatus.firstOrderCompleted;
      case 'PAYMENT_COMPLETED':
        return ReferralStatus.paymentCompleted;
      case 'REWARD_RELEASED':
        return ReferralStatus.rewardReleased;
      case 'EXPIRED':
        return ReferralStatus.expired;
      case 'REJECTED':
        return ReferralStatus.rejected;
      default:
        return ReferralStatus.unknown;
    }
  }

  /// Human-readable label for the UI.
  String get label {
    switch (this) {
      case ReferralStatus.pending:
        return 'Pending';
      case ReferralStatus.registered:
        return 'Joined';
      case ReferralStatus.firstOrderCompleted:
        return 'First order placed';
      case ReferralStatus.paymentCompleted:
        return 'Payment done';
      case ReferralStatus.rewardReleased:
        return 'Reward earned';
      case ReferralStatus.expired:
        return 'Expired';
      case ReferralStatus.rejected:
        return 'Rejected';
      case ReferralStatus.unknown:
        return 'Unknown';
    }
  }

  bool get isTerminal =>
      this == ReferralStatus.rewardReleased ||
      this == ReferralStatus.expired ||
      this == ReferralStatus.rejected;
}

/// The current user's referral code, share link and headline stats.
class MyReferral {
  final String code;
  final String link;
  final int totalReferrals;
  final int successfulReferrals;
  final int pendingReferrals;
  final double totalEarned;

  const MyReferral({
    required this.code,
    required this.link,
    this.totalReferrals = 0,
    this.successfulReferrals = 0,
    this.pendingReferrals = 0,
    this.totalEarned = 0,
  });

  factory MyReferral.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map<String, dynamic>?) ?? const {};
    return MyReferral(
      code: json['code']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      totalReferrals: (stats['totalReferrals'] as num?)?.toInt() ?? 0,
      successfulReferrals:
          (stats['successfulReferrals'] as num?)?.toInt() ?? 0,
      pendingReferrals: (stats['pendingReferrals'] as num?)?.toInt() ?? 0,
      totalEarned: (stats['totalEarned'] as num?)?.toDouble() ?? 0,
    );
  }

  static const empty = MyReferral(code: '', link: '');
}

/// One row in the user's referral history list.
class ReferralHistoryItem {
  final String referralId;
  final String refereeName;
  final DateTime? joinedDate;
  final ReferralStatus status;
  final double rewardAmount;
  final String rewardStatus;
  final DateTime? releasedDate;
  final double pendingReward;
  final String? rejectedReason;

  const ReferralHistoryItem({
    required this.referralId,
    required this.refereeName,
    required this.status,
    this.joinedDate,
    this.rewardAmount = 0,
    this.rewardStatus = 'PENDING',
    this.releasedDate,
    this.pendingReward = 0,
    this.rejectedReason,
  });

  factory ReferralHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return ReferralHistoryItem(
      referralId: json['referralId']?.toString() ?? '',
      refereeName: json['refereeName']?.toString() ?? 'Friend',
      joinedDate: parse(json['joinedDate']),
      status: ReferralStatus.fromApi(json['status']?.toString()),
      rewardAmount: (json['rewardAmount'] as num?)?.toDouble() ?? 0,
      rewardStatus: json['rewardStatus']?.toString() ?? 'PENDING',
      releasedDate: parse(json['releasedDate']),
      pendingReward: (json['pendingReward'] as num?)?.toDouble() ?? 0,
      rejectedReason: json['rejectedReason']?.toString(),
    );
  }
}

/// Programme rules shown on the Refer & Earn home.
class ReferralProgram {
  final bool enabled;
  final String rewardType;
  final double referrerReward;
  final double refereeReward;
  final double minimumOrderValue;

  const ReferralProgram({
    this.enabled = true,
    this.rewardType = 'WALLET_CREDIT',
    this.referrerReward = 0,
    this.refereeReward = 0,
    this.minimumOrderValue = 0,
  });

  factory ReferralProgram.fromJson(Map<String, dynamic> json) {
    return ReferralProgram(
      enabled: json['enabled'] as bool? ?? true,
      rewardType: json['rewardType']?.toString() ?? 'WALLET_CREDIT',
      referrerReward: (json['referrerReward'] as num?)?.toDouble() ?? 0,
      refereeReward: (json['refereeReward'] as num?)?.toDouble() ?? 0,
      minimumOrderValue: (json['minimumOrderValue'] as num?)?.toDouble() ?? 0,
    );
  }
}
