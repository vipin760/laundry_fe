import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class OrderConfirmedScreen extends StatelessWidget {
  const OrderConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Order Confirmed',
      route: '/orders/tracking/confirmed',
    );
  }
}
