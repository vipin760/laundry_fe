import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Payment Methods',
      route: '/profile/payment-methods',
    );
  }
}
