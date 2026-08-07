import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Complete Profile',
      route: '/auth/complete-profile',
    );
  }
}
