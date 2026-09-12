import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/auth/presentation/signup_screen.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

/// A session payload shaped like `AuthResponse`.
Map<String, dynamic> sessionJson({String fullName = 'Mehedi Hasan'}) => {
  'success': true,
  'accessToken': 'access-token',
  'refreshToken': 'refresh-token',
  'expiresIn': 900,
  'user': {'id': 'u1', 'fullName': fullName, 'email': 'user@test.com'},
};

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi({
      'POST /auth/login': ok(sessionJson()),
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
    });
  });

  Future<void> openLogin(WidgetTester tester) async {
    await pumpApp(tester, api: api);
    await goTo(tester, Routes.login);
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  testWidgets('refuses to submit an empty form', (tester) async {
    await openLogin(tester);

    await tester.tap(find.widgetWithText(InkWell, 'Login').last);
    await tester.pumpAndSettle();

    expect(find.text('Phone number or email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(api.bodyOf('POST /auth/login'), isNull);
  });

  testWidgets('signs in and lands on home', (tester) async {
    await openLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, '01712345624');
    await tester.enterText(find.byType(TextFormField).last, 'Password@123');
    await tester.tap(find.widgetWithText(InkWell, 'Login').last);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    // The API takes the identifier in `email` and needs a device id.
    final body = api.bodyOf('POST /auth/login')!;
    expect(body['email'], '01712345624');
    expect(body['password'], 'Password@123');
    expect(body['deviceId'], isNotEmpty);
    expect(body['platform'], isNotNull);
  });

  testWidgets('shows the API message when credentials are rejected', (
    tester,
  ) async {
    api.routes['POST /auth/login'] = apiError(
      'BAD_CREDENTIALS',
      status: 401,
      message: 'Invalid credentials',
    );
    await openLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, '01712345624');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.widgetWithText(InkWell, 'Login').last);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsNothing);
    expect(
      find.text('Wrong phone/email or password. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('the sign up link opens registration', (tester) async {
    await openLogin(tester);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
