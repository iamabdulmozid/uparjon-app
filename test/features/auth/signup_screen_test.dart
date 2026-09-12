import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/core/ui/app_circle_check.dart';
import 'package:uparjon/features/auth/presentation/signup_screen.dart';
import 'package:uparjon/features/home/presentation/home_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';
import 'login_screen_test.dart' show sessionJson;

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi({
      'POST /auth/register': ok(sessionJson(fullName: 'Mehedi Hasan')),
      'GET /users/me': ok({'id': 'u1', 'fullName': 'Mehedi Hasan'}),
    });
  });

  Future<void> openSignup(WidgetTester tester) async {
    await pumpApp(tester, api: api);
    await goTo(tester, Routes.signup);
    expect(find.byType(SignupScreen), findsOneWidget);
  }

  /// Order: full name, phone, email, password, confirm password.
  Future<void> fillValidForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mohammad Mehedi Hasan');
    await tester.enterText(fields.at(1), '01712345624');
    await tester.enterText(fields.at(2), 'mehedi@test.com');
    await tester.enterText(fields.at(3), 'Password@123');
    await tester.enterText(fields.at(4), 'Password@123');
    await tester.pump();
  }

  testWidgets('rejects a malformed phone number and mismatched passwords', (
    tester,
  ) async {
    await openSignup(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mehedi');
    await tester.enterText(fields.at(1), '12345');
    await tester.enterText(fields.at(2), 'not-an-email');
    await tester.enterText(fields.at(3), 'Password@123');
    await tester.enterText(fields.at(4), 'different');
    await tester.tap(find.widgetWithText(InkWell, 'Sign Up').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid Bangladeshi number (01XXXXXXXXX)'),
      findsOneWidget,
    );
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(api.bodyOf('POST /auth/register'), isNull);
  });

  testWidgets('will not continue until the terms are accepted', (tester) async {
    await openSignup(tester);
    await fillValidForm(tester);

    await tester.tap(find.widgetWithText(InkWell, 'Sign Up').last);
    await tester.pumpAndSettle();

    expect(api.bodyOf('POST /auth/register'), isNull);
    expect(find.text('Please accept the Terms & Conditions.'), findsOneWidget);
  });

  testWidgets('registering signs the user straight in', (tester) async {
    await openSignup(tester);
    await fillValidForm(tester);

    await tester.tap(find.byType(AppCircleCheck));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Sign Up').last);
    await tester.pumpAndSettle();

    // The API returns a session, so there is no OTP step in between.
    expect(find.byType(HomeScreen), findsOneWidget);

    final body = api.bodyOf('POST /auth/register')!;
    expect(body['fullName'], 'Mohammad Mehedi Hasan');
    expect(body['mobile'], '01712345624');
    // The backend rejects registration without an email, despite its schema
    // marking the field optional.
    expect(body['email'], 'mehedi@test.com');
    expect(body['password'], 'Password@123');
    // countryCode is required by the backend.
    expect(body['countryCode'], 'BD');
  });

  testWidgets('surfaces a server-side validation error', (tester) async {
    api.routes['POST /auth/register'] = apiError(
      'VALIDATION_ERROR',
      message: 'Validation failed: mobile: Mobile already registered',
    );
    await openSignup(tester);
    await fillValidForm(tester);
    await tester.tap(find.byType(AppCircleCheck));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Sign Up').last);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsNothing);
    expect(find.textContaining('Mobile already registered'), findsOneWidget);
  });
}
