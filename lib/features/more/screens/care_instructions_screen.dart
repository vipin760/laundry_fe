import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class CareInstructionsScreen extends StatelessWidget {
  const CareInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      screenName: 'Care Instructions',
      route: '/more/care-instructions',
    );
  }
}
