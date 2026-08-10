import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laudry_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows LaundryBrew auth screen when unauthenticated',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // The real app theme (AppTheme.lightTheme) pulls Manrope from
    // package:google_fonts, which fetches font files over the network on
    // first use. flutter_test blocks all real HTTP (returns 400), and
    // this app doesn't bundle local .ttf assets for the offline-fallback
    // path either, so building the real theme here would throw. That
    // fetch is fire-and-forget deep inside google_fonts and unrelated to
    // whether the correct screen/text renders, so this test verifies the
    // real auth/router/splash flow against a theme that doesn't depend on
    // it — see LaundryApp's `theme` override, which the real app never
    // supplies (it always renders with AppTheme.lightTheme).
    await tester.pumpWidget(
      ProviderScope(
        child: LaundryApp(theme: ThemeData.light()),
      ),
    );

    // The splash screen decodes its logo through a real dart:ui image
    // codec (needed for its custom split-logo animation) before starting
    // the brand animation that gates navigation to the auth screen. That
    // decode is real, engine-driven async work — not tied to the fake
    // test clock — so it needs actual wall-clock time to resolve.
    // runAsync() steps outside the fake-async test zone to let it do so.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Drive the splash screen's animation to completion and past its
    // post-animation navigation delay, polling in small increments rather
    // than a single big jump. The exact interaction between this app's
    // AnimationController-driven navigation and the fake test clock isn't
    // fully deterministic pump-for-pump, so check after every step
    // instead of guessing the precise total.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Welcome back!').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
