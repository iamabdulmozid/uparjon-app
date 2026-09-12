import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/app/router/routes.dart';
import 'package:uparjon/features/auth/presentation/forgot_password_screen.dart';
import 'package:uparjon/features/auth/presentation/login_screen.dart';
import 'package:uparjon/features/auth/presentation/otp_screen.dart';
import 'package:uparjon/features/auth/presentation/reset_password_screen.dart';

import '../../support/fake_api.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeApi api;

  setUp(() {
    api = FakeApi({
      'POST /auth/forgot-password': ok(null),
      'POST /auth/verify-otp': ok(null),
      'POST /auth/reset-password': ok(null),
    });
  });

  Future<void> openForgotPassword(WidgetTester tester) async {
    await pumpApp(tester, api: api);
    await goTo(tester, Routes.forgotPassword);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  }

  testWidgets('walks request OTP -> verify -> new password -> login', (
    tester,
  ) async {
    await openForgotPassword(tester);

    // 1. request the code
    await tester.enterText(find.byType(TextFormField), '01712345624');
    await tester.tap(find.widgetWithText(InkWell, 'Send Code'));
    await tester.pumpAndSettle();

    expect(find.byType(OtpScreen), findsOneWidget);
    expect(
      api.bodyOf('POST /auth/forgot-password')!['emailOrPhone'],
      '01712345624',
    );
    // The number is masked on the verification screen.
    expect(find.textContaining('+88017******24'), findsOneWidget);

    // 2. enter the six digits
    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    final verify = api.bodyOf('POST /auth/verify-otp')!;
    expect(verify['otp'], '123456');
    expect(verify['emailOrPhone'], '01712345624');

    // 3. choose a new password
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPassword@123');
    await tester.enterText(fields.at(1), 'NewPassword@123');
    await tester.tap(find.widgetWithText(InkWell, 'Save Password'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final reset = api.bodyOf('POST /auth/reset-password')!;
    // The verified OTP is sent as `token`.
    expect(reset['token'], '123456');
    expect(reset['newPassword'], 'NewPassword@123');
  });

  testWidgets('a wrong code keeps the user on the OTP screen', (tester) async {
    api.routes['POST /auth/verify-otp'] = apiError(
      'BUSINESS_ERROR',
      message: 'Invalid or expired OTP',
    );
    await openForgotPassword(tester);

    await tester.enterText(find.byType(TextFormField), 'user@test.com');
    await tester.tap(find.widgetWithText(InkWell, 'Send Code'));
    await tester.pumpAndSettle();

    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '9');
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.textContaining('Invalid or expired OTP'), findsOneWidget);
  });
}
