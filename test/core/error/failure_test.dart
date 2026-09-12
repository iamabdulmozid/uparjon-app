import 'package:flutter_test/flutter_test.dart';
import 'package:uparjon/core/error/app_exception.dart';
import 'package:uparjon/core/error/failure.dart';

void main() {
  group('Failure.tidy', () {
    test('collapses the repetition the backend emits', () {
      // Verbatim from POST /auth/register on staging.
      expect(
        Failure.tidy(
          'Validation failed: countryCode: Country is required, '
          'countryCode: Country is required',
        ),
        'Country is required.',
      );
    });

    test('keeps distinct problems, one sentence each', () {
      expect(
        Failure.tidy(
          'Validation failed: email: Email is required, '
          'mobile: Mobile is invalid',
        ),
        'Email is required. Mobile is invalid.',
      );
    });

    test('leaves a plain message alone', () {
      expect(Failure.tidy('Email is required.'), 'Email is required.');
    });
  });

  group('Failure.from', () {
    test('maps the code the live API returns for a dead token', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.unauthorized,
          errorCode: ApiErrorCodes.unauthorized,
          statusCode: 401,
        ),
      );
      expect(failure, isA<AuthFailure>());
    });

    test('maps bad credentials without leaking whether the account exists', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.unauthorized,
          errorCode: ApiErrorCodes.badCredentials,
          message: 'Invalid credentials',
          statusCode: 401,
        ),
      );
      expect(
        failure.message,
        'Wrong phone/email or password. Please try again.',
      );
    });

    test('tidies a validation message on the way to the user', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.badRequest,
          errorCode: ApiErrorCodes.validationError,
          message:
              'Validation failed: email: Email is required, '
              'email: Email is required',
          statusCode: 400,
        ),
      );
      expect(failure.message, 'Email is required.');
    });
  });
}
