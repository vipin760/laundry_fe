import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class BlogScreen extends StatelessWidget {
  const BlogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Blog',
      route: '/more/blog',
    );
  }
}
