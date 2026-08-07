import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class DryCleaningScreen extends StatelessWidget {
  const DryCleaningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Dry Cleaning Service',
      route: '/services/dry-cleaning',
    );
  }
}
