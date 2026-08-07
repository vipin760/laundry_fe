import 'package:flutter/material.dart';

import '../../../shared/widgets/legal_document_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      assetPath: 'assets/legal/privacy_policy.md',
    );
  }
}
