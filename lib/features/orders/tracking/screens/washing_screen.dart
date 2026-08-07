import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class WashingScreen extends StatelessWidget {
  const WashingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Washing / Itemized',
      route: '/orders/tracking/washing',
    );
  }
}
