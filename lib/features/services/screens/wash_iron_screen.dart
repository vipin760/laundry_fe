import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class WashIronScreen extends StatelessWidget {
  const WashIronScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Wash & Iron Service',
      route: '/services/wash-iron',
    );
  }
}
