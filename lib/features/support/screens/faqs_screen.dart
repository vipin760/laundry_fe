import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'FAQs',
      route: '/support/faqs',
    );
  }
}
