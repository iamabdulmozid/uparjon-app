import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('refreshes the token once and replays the rejected request', (
    tester,
  ) async {
    final api = FakeApi(
      {
        // Staging returns UNAUTHORIZED here, not the documented INVALID_TOKEN.
        'POST /auth/refresh': ok({
          'accessToken': 'fresh-access',
          'refreshToken': 'fresh-refresh',
        }),
      },
      sequences: {
        'GET /users/me': [
          apiError('UNAUTHORIZED', status: 401, message: 'Session expired'),
          ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
        ],
      },
    );

    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);

    // The stale token was refreshed and the profile call retried, so the
    // session survived and the user is signed in.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(api.callCount('POST /auth/refresh'), 1);
    expect(api.callCount('GET /users/me'), 2);
    expect(api.bodyOf('POST /auth/refresh')!['refreshToken'], 'test-refresh');
  });

  testWidgets('signs the user out when the refresh itself fails', (
    tester,
  ) async {
    final api = FakeApi({
      'GET /users/me': apiError('UNAUTHORIZED', status: 401),
      'POST /auth/refresh': apiError('UNAUTHORIZED', status: 401),
    });

    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);

    // Guard sends a session-less user to login rather than a broken home.
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
