import 'package:flutter/material.dart';
import '../../referral/screens/refer_earn_home_screen.dart';

/// Profile → Referral tab.
///
/// Thin wrapper over the shared [ReferralHomeBody] from the `referral`
/// feature, so the profile tab and the Refer & Earn screen render the same
/// live data (code, stats, apply-code card, recent referrals) from the same
/// provider — one source of truth, no duplicated API layer.
class ReferralTab extends StatelessWidget {
  const ReferralTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReferralHomeBody();
  }
}
