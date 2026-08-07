import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class SecureOrdersScreen extends StatelessWidget {
  const SecureOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Secure Orders',
      route: '/profile/secure-orders',
    );
  }
}
