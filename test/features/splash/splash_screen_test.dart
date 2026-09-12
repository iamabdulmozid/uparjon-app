import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/onboarding/presentation/welcome_screen.dart';
import 'package:uparjon/features/splash/presentation/splash_screen.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('shows the splash, then the welcome screen on first launch', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(SplashScreen), findsOneWidget);

    await settleSplash(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('skips onboarding once it has been completed', (tester) async {
    await pumpApp(tester, prefs: {'onboarding_done': true});

    await settleSplash(tester);

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
