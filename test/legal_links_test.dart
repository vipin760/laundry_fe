import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:laudry_app/core/utils/legal_links.dart';
import 'package:laudry_app/features/account_deletion/screens/privacy_security_screen.dart';

/// Records the last call made through [UrlLauncherPlatform] instead of
/// touching a real browser/OS URL handler.
class _FakeUrlLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  String? lastUrl;
  PreferredLaunchMode? lastMode;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    lastMode = options.mode;
    return true;
  }
}

void main() {
  late _FakeUrlLauncher fakeLauncher;

  setUp(() {
    fakeLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeLauncher;
  });

  group('LegalLinks', () {
    test('privacyPolicy and termsAndConditions point at the public site', () {
      expect(LegalLinks.privacyPolicy.toString(), 'https://laundrybrew.com/privacy-policy');
      expect(LegalLinks.termsAndConditions.toString(),
          'https://laundrybrew.com/terms-and-conditions');
    });

    testWidgets('openPrivacyPolicy launches the privacy URL in an in-app browser view',
        (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) => MaterialApp(
            home: ElevatedButton(
              onPressed: () => LegalLinks.openPrivacyPolicy(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastUrl, LegalLinks.privacyPolicy.toString());
      expect(fakeLauncher.lastMode, PreferredLaunchMode.inAppBrowserView);
    });

    testWidgets('openTermsAndConditions launches the terms URL in an in-app browser view',
        (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) => MaterialApp(
            home: ElevatedButton(
              onPressed: () => LegalLinks.openTermsAndConditions(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastUrl, LegalLinks.termsAndConditions.toString());
      expect(fakeLauncher.lastMode, PreferredLaunchMode.inAppBrowserView);
    });
  });

  group('PrivacySecurityScreen', () {
    testWidgets('Privacy Policy tile opens the public privacy URL', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySecurityScreen()));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastUrl, LegalLinks.privacyPolicy.toString());
      expect(fakeLauncher.lastMode, PreferredLaunchMode.inAppBrowserView);
    });

    testWidgets('Terms & Conditions tile opens the public terms URL', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySecurityScreen()));
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastUrl, LegalLinks.termsAndConditions.toString());
      expect(fakeLauncher.lastMode, PreferredLaunchMode.inAppBrowserView);
    });
  });
}
