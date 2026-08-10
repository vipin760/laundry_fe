import '../../../core/api/api_client.dart';
import '../models/delete_account_models.dart';

/// Data-access layer for the account-deletion backend endpoints.
class AccountDeletionApi {
  const AccountDeletionApi();

  /// POST /account/delete/request
  Future<DeleteRequestResult> request({
    required DeleteReason reason,
    String? comment,
  }) async {
    final res = await ApiClient.instance.post('/account/delete/request', data: {
      'reason': reason.apiValue,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    return DeleteRequestResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /account/delete/send-otp
  Future<void> sendOtp() async {
    await ApiClient.instance.post('/account/delete/send-otp', data: {});
  }

  /// POST /account/delete/verify
  Future<VerifyResult> verify({
    required VerificationMethod method,
    String? password,
    String? otp,
  }) async {
    final res = await ApiClient.instance.post('/account/delete/verify', data: {
      'method': method.apiValue,
      'password': ?password,
      'otp': ?otp,
    });
    return VerifyResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /account/delete/confirm — irreversible.
  /// [verificationToken] is only needed when the backend requires
  /// re-verification (REQUIRE_DELETE_VERIFICATION=true); otherwise omit it.
  Future<String> confirm([String? verificationToken]) async {
    final res = await ApiClient.instance.post('/account/delete/confirm', data: {
      if (verificationToken != null && verificationToken.isNotEmpty)
        'verificationToken': verificationToken,
    });
    final data = res.data as Map<String, dynamic>;
    return data['message']?.toString() ?? 'Your account has been deleted.';
  }
}
