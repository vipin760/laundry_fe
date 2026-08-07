import 'package:flutter/material.dart';

import '../../referral/screens/refer_earn_home_screen.dart';

/// Profile → Refer & Earn entry point.
///
/// Delegates to the real referral home (code, share link, live stats and
/// referral history) from the `referral` feature. Kept as a thin wrapper so the
/// existing profile menu item and router route (`/profile/refer-earn`) continue
/// to work unchanged.
class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReferEarnHomeScreen();
  }
}
