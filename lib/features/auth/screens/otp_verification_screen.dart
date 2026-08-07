import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'OTP Verification',
      route: '/auth/verify-otp',
    );
  }
}
