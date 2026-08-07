import '../../../core/api/api_client.dart';
import '../models/referral_models.dart';

/// Thin data-access layer for the Refer & Earn backend endpoints.
/// Uses the shared Dio [ApiClient] (auth cookie/token already attached).
class ReferralApi {
  const ReferralApi();

  /// GET /referral/dashboard — combined home payload (code, stats, recent, rules).
  Future<({
    MyReferral my,
    List<ReferralHistoryItem> recent,
    ReferralProgram program,
    bool hasReferrer,
  })> fetchDashboard() async {
    final res = await ApiClient.instance.get('/referral/dashboard');
    final data = res.data as Map<String, dynamic>;
    final recent = (data['recent'] as List<dynamic>? ?? [])
        .map((e) => ReferralHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      my: MyReferral.fromJson(data),
      recent: recent,
      program: ReferralProgram.fromJson(
        (data['program'] as Map<String, dynamic>?) ?? const {},
      ),
      // Default true so the apply-code card stays hidden if the backend
      // predates this field (fail-closed for the promo UI).
      hasReferrer: data['hasReferrer'] as bool? ?? true,
    );
  }

  /// GET /referral/my
  Future<MyReferral> fetchMy() async {
    final res = await ApiClient.instance.get('/referral/my');
    return MyReferral.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /referral/history?page=&limit=
  Future<List<ReferralHistoryItem>> fetchHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final res = await ApiClient.instance.get(
      '/referral/history',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => ReferralHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /referral/validate — returns referrer name if valid, else throws.
  Future<String> validate(String code) async {
    final res = await ApiClient.instance.post(
      '/referral/validate',
      data: {'code': code},
    );
    return (res.data as Map<String, dynamic>)['referrerName']?.toString() ??
        'A friend';
  }

  /// POST /referral/apply — bind a referral code to the current user.
  /// [context] carries anti-abuse signals (deviceId, emulator/vpn flags…).
  Future<void> apply(String code, {Map<String, dynamic>? context}) async {
    await ApiClient.instance.post('/referral/apply', data: {
      'code': code,
      ...?context,
    });
  }
}
