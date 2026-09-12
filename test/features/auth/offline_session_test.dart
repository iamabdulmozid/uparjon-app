import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

/// Reopening the app with no connectivity must not sign the user out:
/// the tokens are still valid, the phone just cannot reach the server.
void main() {
  testWidgets('a stored session survives a cold start with no internet', (
    tester,
  ) async {
    final api = FakeApi({}, offline: true);

    await pumpApp(tester, api: api, signedIn: true);
    await settleSplash(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('the cached profile is shown while offline', (tester) async {
    // First launch online: the profile is fetched and cached.
    final online = FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mohammad Mehedi Hasan'}),
    });
    await pumpApp(tester, api: online, signedIn: true);
    await settleSplash(tester);
    expect(find.text('Hi, Mohammad'), findsOneWidget);

    // Relaunch with no network: the greeting comes from the cache.
    final offline = FakeApi({}, offline: true);
    await pumpApp(
      tester,
      api: offline,
      signedIn: true,
      keepSecureStorage: true,
    );
    await settleSplash(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hi, Mohammad'), findsOneWidget);
  });

  testWidgets('a server outage does not sign the user out', (tester) async {
    final api = FakeApi({
      'GET /users/me': apiError('INTERNAL_SERVER_ERROR', status: 500),
    });

    await pumpApp(tester, api: api, signedIn: true);
    await settleSplash(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a genuinely rejected token still signs the user out', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /users/me': apiError('UNAUTHORIZED', status: 401),
      'POST /auth/refresh': apiError('UNAUTHORIZED', status: 401),
    });

    // Onboarding is behind them, so a signed-out user belongs on Login.
    await pumpApp(
      tester,
      api: api,
      signedIn: true,
      prefs: {'onboarding_done': true},
    );
    await settleSplash(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
