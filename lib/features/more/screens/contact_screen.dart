import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Contact Us',
      route: '/more/contact',
    );
  }
}
