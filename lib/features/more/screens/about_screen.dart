import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'About Us',
      route: '/more/about',
    );
  }
}
