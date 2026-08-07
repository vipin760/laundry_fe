import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders a bundled legal document (Terms & Conditions, Privacy Policy, …)
/// from a markdown asset, so the content ships with the app and needs no
/// network access.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1F36),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2453FF)),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Unable to load this document.'));
            }
            return Markdown(
              data: snapshot.data!,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              onTapLink: (text, href, title) {
                if (href == null) return;
                launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
              },
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1F36),
                ),
                h2: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1F36),
                ),
                p: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF374151),
                ),
                listBullet: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
                a: const TextStyle(color: Color(0xFF2453FF)),
                strong: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          },
        ),
      ),
    );
  }
}
