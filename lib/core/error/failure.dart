import 'app_exception.dart';

/// User-facing failure surfaced by controllers to the UI.
///
/// The [message] here is safe to show to users (and will move to l10n keys
/// once localization is wired up). [code] is carried through from the API so
/// callers can branch on it.
sealed class Failure {
  const Failure(this.message, {this.code, this.fieldErrors = const {}});

  final String message;

  /// The API `errorCode`, when the failure came from the server.
  final String? code;

  /// Field-level validation errors, keyed by form field name.
  final Map<String, String> fieldErrors;

  /// Collapses the repetition the backend emits for some validation errors,
  /// e.g. `"Validation failed: countryCode: Country is required, countryCode:
  /// Country is required"` — the user should read it once.
  static String tidy(String raw) {
    final withoutPrefix = raw.replaceFirst(
      RegExp(r'^\s*Validation failed:\s*'),
      '',
    );
    final seen = <String>{};
    final parts = <String>[];
    for (final chunk in withoutPrefix.split(',')) {
      final text = chunk.contains(':')
          ? chunk.split(':').sublist(1).join(':').trim()
          : chunk.trim();
      if (text.isEmpty || !seen.add(text.toLowerCase())) continue;
      parts.add(text);
    }
    if (parts.isEmpty) return raw;
    final joined = parts.join('. ');
    return joined.endsWith('.') ? joined : '$joined.';
  }

  /// Maps a caught object (usually an [AppException]) to a [Failure].
  factory Failure.from(Object error) {
    if (error is Failure) return error;
    if (error is! AppException) return const UnknownFailure();

    final code = error.errorCode;
    final serverMessage = error.message == null
        ? null
        : Failure.tidy(error.message!);

    // Branch on the API's error code first — it is stable, the message is not.
    return switch (code) {
      ApiErrorCodes.badCredentials || ApiErrorCodes.invalidCredentials =>
        AuthFailure('Wrong phone/email or password. Please try again.', code),
      ApiErrorCodes.invalidToken || ApiErrorCodes.unauthorized => AuthFailure(
        'Your session has expired. Please log in again.',
        code,
      ),
      ApiErrorCodes.accountLocked ||
      ApiErrorCodes.accountDisabled ||
      ApiErrorCodes.accountSuspended => AccountRestrictedFailure(
        serverMessage ?? 'This account is not active. Please contact support.',
        code: code,
      ),
      ApiErrorCodes.validationError => ValidationFailure(
        serverMessage ?? 'Please check the details you entered.',
        fieldErrors: error.fieldErrors,
      ),
      // Domain rules the user can act on. Never an authentication problem,
      // even though the server answers some of them with a 403.
      ApiErrorCodes.campaignNotEligible ||
      ApiErrorCodes.kycRequired ||
      ApiErrorCodes.insufficientBalance ||
      ApiErrorCodes.duplicateRequest ||
      ApiErrorCodes.businessError => BusinessFailure(
        serverMessage ?? 'This action is not available right now.',
        code: code!,
      ),
      ApiErrorCodes.illegalState => _illegalState(error.message, code!),
      _ => switch (error.kind) {
        AppExceptionKind.network => const NetworkFailure(),
        AppExceptionKind.timeout => const NetworkFailure(
          'The request timed out. Please try again.',
        ),
        AppExceptionKind.unauthorized => AuthFailure(
          'Your session has expired. Please log in again.',
          code,
        ),
        AppExceptionKind.badRequest => ValidationFailure(
          serverMessage ?? 'The request was rejected.',
          fieldErrors: error.fieldErrors,
          code: code,
        ),
        AppExceptionKind.server => ServerFailure(code: code),
        AppExceptionKind.parsing ||
        AppExceptionKind.unknown => UnknownFailure(code: code),
      },
    };
  }

  /// `ILLEGAL_STATE` is what the API returns for a rule it treats as an
  /// impossible state, and it arrives as a **500**. The generic mapping would
  /// call that an outage and invite a retry, which is exactly wrong: none of
  /// these can ever succeed on a second attempt.
  ///
  /// The server text is diagnostic rather than user-facing (`Duplicate
  /// transaction: referenceId survey:… has already been processed`,
  /// `Insufficient watch duration. Required: 24s, watched: 10s`), so it is
  /// matched here but never shown.
  static Failure _illegalState(String? serverText, String code) {
    final text = serverText ?? '';

    final message = switch (text) {
      _
          when text.contains('already been rewarded') ||
              text.contains('already been processed') ||
              text.contains('Duplicate transaction') =>
        'You have already been rewarded for this one.',
      _ when text.contains('Insufficient watch duration') =>
        'Please watch the whole video to earn this reward.',
      _ => 'This action is not available right now.',
    };

    return BusinessFailure(message, code: code);
  }

  @override
  String toString() => '$runtimeType($code, $message)';
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

final class ServerFailure extends Failure {
  const ServerFailure({
    String message = 'Something went wrong on our side. Please try again.',
    super.code,
  }) : super(message);
}

final class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Your session has expired. Please log in.',
    String? code,
  ]) : super(code: code);
}

/// Locked, disabled or suspended account — needs a support path, not a retry.
final class AccountRestrictedFailure extends Failure {
  const AccountRestrictedFailure(super.message, {super.code});
}

/// A domain rule refused the action: not eligible, KYC needed, out of balance,
/// already submitted. Callers branch on [code] to decide what to do next.
final class BusinessFailure extends Failure {
  const BusinessFailure(super.message, {required String super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.fieldErrors, String? code})
    : super(code: code ?? ApiErrorCodes.validationError);
}

final class UnknownFailure extends Failure {
  const UnknownFailure({
    String message = 'Something went wrong. Please try again.',
    super.code,
  }) : super(message);
}
