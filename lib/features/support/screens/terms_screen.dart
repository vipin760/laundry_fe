import 'package:flutter/material.dart';

import '../../../shared/widgets/legal_document_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms & Conditions',
      assetPath: 'assets/legal/terms_conditions.md',
    );
  }
}
