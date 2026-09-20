/// Typed exception thrown by the data layer (network/storage).
///
/// Data sources throw [AppException]; repositories/controllers convert it to
/// a [Failure] (see `failure.dart`) before it reaches the UI.
class AppException implements Exception {
  const AppException(
    this.kind, {
    this.message,
    this.statusCode,
    this.errorCode,
    this.fieldErrors = const {},
  });

  final AppExceptionKind kind;

  /// Server-provided or diagnostic message (not necessarily user-facing).
  final String? message;
  final int? statusCode;

  /// Stable machine-readable code from the API envelope, e.g.
  /// `BAD_CREDENTIALS`. Branch on this, never on [message] — the backend
  /// treats the human text as changeable.
  final String? errorCode;

  /// Field-level validation errors, keyed by form field name.
  final Map<String, String> fieldErrors;

  @override
  String toString() =>
      'AppException($kind, code: $errorCode, status: $statusCode, $message)';
}

enum AppExceptionKind {
  /// No connectivity / DNS / socket-level problems.
  network,

  /// Request or response timed out.
  timeout,

  /// 401/403 — invalid or expired session.
  unauthorized,

  /// 4xx — the request was understood but rejected (validation etc.).
  badRequest,

  /// 5xx — server-side error.
  server,

  /// Response could not be parsed into the expected model.
  parsing,

  /// Anything else.
  unknown,
}

/// Error codes the app branches on. See `API_Collection/docs/error-codes.md`.
abstract final class ApiErrorCodes {
  static const String badCredentials = 'BAD_CREDENTIALS';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String invalidToken = 'INVALID_TOKEN';

  /// What the live API actually returns for an expired/garbage bearer token
  /// (the handover docs say `INVALID_TOKEN`; staging says this).
  static const String unauthorized = 'UNAUTHORIZED';
  static const String accessDenied = 'ACCESS_DENIED';
  static const String accountLocked = 'ACCOUNT_LOCKED';
  static const String accountDisabled = 'ACCOUNT_DISABLED';
  static const String accountSuspended = 'ACCOUNT_SUSPENDED';
  static const String validationError = 'VALIDATION_ERROR';
  static const String businessError = 'BUSINESS_ERROR';
  static const String duplicateRequest = 'DUPLICATE_REQUEST';
  static const String kycRequired = 'KYC_REQUIRED';

  /// The server's catch-all for "this cannot happen twice". It arrives as a
  /// **500**, but it is a domain rule, not an outage: replaying a
  /// reward-producing submit answers
  /// `Duplicate transaction: … has already been processed`.
  static const String illegalState = 'ILLEGAL_STATE';
  static const String campaignNotEligible = 'CAMPAIGN_NOT_ELIGIBLE';
  static const String insufficientBalance = 'INSUFFICIENT_BALANCE';
}
