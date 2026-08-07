import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Help & Support',
      route: '/support',
    );
  }
}
