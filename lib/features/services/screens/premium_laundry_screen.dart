import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class PremiumLaundryScreen extends StatelessWidget {
  const PremiumLaundryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Premium Laundry Service',
      route: '/services/premium-laundry',
    );
  }
}
