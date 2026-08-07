import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class DeliveredScreen extends StatelessWidget {
  const DeliveredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Delivered',
      route: '/orders/tracking/delivered',
    );
  }
}
