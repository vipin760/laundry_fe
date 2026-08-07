import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class OrderReviewScreen extends StatelessWidget {
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Order Review',
      route: '/orders/review',
    );
  }
}
