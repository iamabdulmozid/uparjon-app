import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';
import 'package:uparjon/features/menu/presentation/menu_screen.dart';
import 'package:uparjon/features/menu/presentation/widgets/logout_confirm_sheet.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi({
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
      'POST /auth/logout': ok(null, message: 'Logout successful'),
    });
  });

  /// Signs in, then opens the Menu tab from the bottom navigation.
  Future<void> openMenu(WidgetTester tester) async {
    await pumpApp(tester, api: api, signedIn: true);
    await goTo(tester, Routes.home);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsOneWidget);
  }

  testWidgets('lists every menu destination', (tester) async {
    await openMenu(tester);

    for (final label in [
      'Profile',
      'Settings',
      'Language',
      'Default Withdraw Method',
      'Watch Tutorial',
      'About Us',
      'Terms & Condition',
      'Help & Support',
      'FAQ',
      'Log Out',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing row: $label');
    }
  });

  testWidgets('log out asks first, and cancelling keeps the session', (
    tester,
  ) async {
    await openMenu(tester);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.byType(LogoutConfirmSheet), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(MenuScreen), findsOneWidget);
    expect(api.bodyOf('POST /auth/logout'), isNull);
  });

  testWidgets('confirming revokes the session and returns to login', (
    tester,
  ) async {
    await openMenu(tester);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Log Out').last);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // The refresh token is handed to the API so the session dies server-side.
    expect(api.bodyOf('POST /auth/logout')!['refreshToken'], 'test-refresh');
  });

  testWidgets('still signs out locally when the logout call fails', (
    tester,
  ) async {
    api.routes['POST /auth/logout'] = apiError(
      'INTERNAL_SERVER_ERROR',
      status: 500,
    );
    await openMenu(tester);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Log Out').last);
    await tester.pumpAndSettle();

    // A failing server must not strand the user in a signed-in shell.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
