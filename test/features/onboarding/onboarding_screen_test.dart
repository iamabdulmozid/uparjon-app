import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/onboarding/presentation/onboarding_content.dart';
import 'package:uparjon/features/onboarding/presentation/onboarding_screen.dart';
import 'package:uparjon/features/onboarding/presentation/welcome_screen.dart';

import '../../support/pump_app.dart';

/// Opens the carousel through the real flow: splash → welcome → onboarding.
Future<void> openOnboarding(WidgetTester tester) async {
  await pumpApp(tester);
  await settleSplash(tester);
  await tester.tap(find.text('Explore Uparjon'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the welcome CTA opens the carousel on the first slide', (
    tester,
  ) async {
    await openOnboarding(tester);

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text(onboardingSlides.first.eyebrow), findsOneWidget);
  });

  testWidgets('the next button advances through every slide, then finishes', (
    tester,
  ) async {
    await openOnboarding(tester);

    for (var i = 1; i < onboardingSlides.length; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pumpAndSettle();
      expect(find.text(onboardingSlides[i].eyebrow), findsOneWidget);
    }

    // Tapping on the last slide leaves onboarding for good.
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done'), isTrue);
  });

  testWidgets('swiping moves between slides', (tester) async {
    await openOnboarding(tester);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text(onboardingSlides[1].eyebrow), findsOneWidget);
  });

  testWidgets('skip leaves onboarding and records completion', (tester) async {
    await openOnboarding(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done'), isTrue);
  });
}
