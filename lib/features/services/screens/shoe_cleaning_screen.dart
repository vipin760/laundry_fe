import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class ShoeCleaningScreen extends StatelessWidget {
  const ShoeCleaningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Shoe Cleaning Service',
      route: '/services/shoe-cleaning',
    );
  }
}
