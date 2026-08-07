// Account-deletion data models — mirror the backend contract
// (laundry_be/src/account-deletion).

/// Reason options shown to the user (value must match backend DeleteReason).
enum DeleteReason {
  privacyConcerns('PRIVACY_CONCERNS', 'Privacy concerns'),
  noLongerUsing('NO_LONGER_USING', 'No longer using the app'),
  createdAnother('CREATED_ANOTHER_ACCOUNT', 'Created another account'),
  tooExpensive('TOO_EXPENSIVE', 'Too expensive'),
  poorService('POOR_SERVICE', 'Poor service'),
  other('OTHER', 'Other');

  const DeleteReason(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Verification method the user chooses to prove identity.
enum VerificationMethod {
  password('PASSWORD'),
  otp('OTP');

  const VerificationMethod(this.apiValue);
  final String apiValue;
}

/// Response of POST /account/delete/request.
class DeleteRequestResult {
  final String deleteRequestId;
  final String status;
  final double walletBalance;

  /// When false, the user can confirm deletion directly (already logged in).
  final bool verificationRequired;

  const DeleteRequestResult({
    required this.deleteRequestId,
    required this.status,
    this.walletBalance = 0,
    this.verificationRequired = false,
  });

  factory DeleteRequestResult.fromJson(Map<String, dynamic> json) {
    return DeleteRequestResult(
      deleteRequestId: json['deleteRequestId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING_VERIFICATION',
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      verificationRequired: json['verificationRequired'] as bool? ?? false,
    );
  }
}

/// Response of POST /account/delete/verify.
class VerifyResult {
  final bool verified;
  final String verificationToken;
  final int expiresInSeconds;

  const VerifyResult({
    required this.verified,
    required this.verificationToken,
    this.expiresInSeconds = 600,
  });

  factory VerifyResult.fromJson(Map<String, dynamic> json) {
    return VerifyResult(
      verified: json['verified'] as bool? ?? false,
      verificationToken: json['verificationToken']?.toString() ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 600,
    );
  }
}
