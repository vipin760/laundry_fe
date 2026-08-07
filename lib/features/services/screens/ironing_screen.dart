import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class IroningScreen extends StatelessWidget {
  const IroningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Ironing Service',
      route: '/services/ironing',
    );
  }
}
