import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Canonical, publicly hosted legal documents for LaundryBrew.
///
/// The website (laundrybrew.com) is the single source of truth for Privacy
/// Policy / Terms & Conditions content — every in-app entry point that needs
/// to show these documents should open them here rather than embedding or
/// re-hosting the text inside the app.
abstract final class LegalLinks {
  static final Uri privacyPolicy = Uri.parse('https://laundrybrew.com/privacy-policy');
  static final Uri termsAndConditions =
      Uri.parse('https://laundrybrew.com/terms-and-conditions');

  /// Opens the Privacy Policy in the platform's in-app browser (Custom Tabs
  /// on Android, SFSafariViewController on iOS).
  static Future<void> openPrivacyPolicy(BuildContext context) =>
      _open(context, privacyPolicy);

  /// Opens the Terms & Conditions in the platform's in-app browser (Custom
  /// Tabs on Android, SFSafariViewController on iOS).
  static Future<void> openTermsAndConditions(BuildContext context) =>
      _open(context, termsAndConditions);

  static Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched && context.mounted) _showLaunchError(context);
    } catch (_) {
      if (context.mounted) _showLaunchError(context);
    }
  }

  static void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the page. Please check your connection and try again.'),
      ),
    );
  }
}
