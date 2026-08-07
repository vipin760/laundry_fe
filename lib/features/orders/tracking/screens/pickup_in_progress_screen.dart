import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class PickupInProgressScreen extends StatelessWidget {
  const PickupInProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Pickup In Progress',
      route: '/orders/tracking/pickup',
    );
  }
}
