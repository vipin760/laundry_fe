import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'More Menu',
      route: '/more',
    );
  }
}
