import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Order Success',
      route: '/orders/success',
    );
  }
}
