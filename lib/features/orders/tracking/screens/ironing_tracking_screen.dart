import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class IroningTrackingScreen extends StatelessWidget {
  const IroningTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Ironing / Brewing',
      route: '/orders/tracking/ironing',
    );
  }
}
