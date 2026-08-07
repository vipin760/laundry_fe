import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class WashFoldScreen extends StatelessWidget {
  const WashFoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Wash & Fold Service',
      route: '/services/wash-fold',
    );
  }
}
