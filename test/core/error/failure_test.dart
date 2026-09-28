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

    // Replaying a survey the server has already paid out answers
    // `500 ILLEGAL_STATE` with "Duplicate transaction: ... has already been
    // processed". The generic 5xx mapping calls that an outage and invites a
    // retry that can never succeed.
    test('reads a replayed submission as already done, not an outage', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.server,
          errorCode: ApiErrorCodes.illegalState,
          message:
              'Duplicate transaction: referenceId survey:011928aa for type '
              'BONUS has already been processed',
          statusCode: 500,
        ),
      );

      expect(failure, isA<BusinessFailure>());
      expect(failure.message, 'You have already been rewarded for this one.');
      expect(failure.message, isNot(contains('Duplicate transaction')));
    });

    test('tells the user to finish the video, not to retry', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.server,
          errorCode: ApiErrorCodes.illegalState,
          message: 'Insufficient watch duration. Required: 24s, watched: 10s',
          statusCode: 500,
        ),
      );

      expect(failure, isA<BusinessFailure>());
      expect(
        failure.message,
        'Please watch the whole video to earn this reward.',
      );
      expect(failure.message, isNot(contains('Required')));
    });

    // Media quiz guide v2 answers a repeated claim with a 409. Mapped by
    // status alone it would read as a form validation error.
    test('an ALREADY_CLAIMED conflict says the reward was paid', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.badRequest,
          errorCode: ApiErrorCodes.alreadyClaimed,
          message:
              'You have already completed and claimed the reward for this ad',
          statusCode: 409,
        ),
      );

      expect(failure, isA<BusinessFailure>());
      expect(failure.code, ApiErrorCodes.alreadyClaimed);
      expect(failure.message, 'You have already been rewarded for this one.');
    });

    for (final (text, expected) in [
      (
        'Reward already exists for this ad view',
        'You have already been rewarded for this one.',
      ),
      (
        'You must view the ad before submitting answers',
        'Please watch the whole video to earn this reward.',
      ),
    ]) {
      test('maps the ad quiz rule "$text"', () {
        final failure = Failure.from(
          AppException(
            AppExceptionKind.server,
            errorCode: ApiErrorCodes.illegalState,
            message: text,
            statusCode: 500,
          ),
        );
        expect(failure.message, expected);
      });
    }

    test('keeps other illegal-state failures generic', () {
      final failure = Failure.from(
        const AppException(
          AppExceptionKind.server,
          errorCode: ApiErrorCodes.illegalState,
          message: 'Survey slot pool exhausted',
          statusCode: 500,
        ),
      );

      expect(failure, isA<BusinessFailure>());
      expect(failure.message, 'This action is not available right now.');
    });
  });
}
