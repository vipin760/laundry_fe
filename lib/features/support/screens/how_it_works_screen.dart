import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'How It Works',
      route: '/support/how-it-works',
    );
  }
}
