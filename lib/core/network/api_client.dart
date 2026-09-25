import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../error/app_exception.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Riverpod entry point for the shared HTTP client.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));

/// Thin wrapper around dio — the only place in the app that imports dio
/// (besides the interceptors). Features talk to repositories, repositories
/// talk to [ApiClient], so the HTTP library stays swappable.
///
/// The backend wraps every response in
/// `{success, message, data, errorCode, timestamp}`; this client unwraps
/// `data` on success and throws a typed [AppException] carrying `errorCode`
/// otherwise.
class ApiClient {
  ApiClient(Ref ref, {Dio? dio})
    : _dio = _configure(dio ?? Dio(_baseOptions()), ref);

  final Dio _dio;

  static BaseOptions _baseOptions() => BaseOptions(
    baseUrl: AppEnv.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
    // Let *every* status through so the envelope's errorCode can be read.
    //
    // 5xx included: the API answers domain rules it treats as impossible
    // states with a 500 carrying `ILLEGAL_STATE` ("You have already been
    // rewarded for this ad", "Insufficient watch duration"). Stopping at
    // `< 500` made dio throw before [unwrap] ever saw the body, so those
    // codes were lost and every one of them reached the user as a generic
    // "something went wrong on our side".
    validateStatus: (_) => true,
  );

  /// Attaches the app's interceptors. An injected [dio] is configured too, so
  /// tests exercise the same auth/refresh behaviour as production.
  static Dio _configure(Dio dio, Ref ref) {
    dio.interceptors.addAll([
      AuthInterceptor(ref, dio),
      if (!AppEnv.isProd) LoggingInterceptor(),
    ]);
    return dio;
  }

  /// A clone of [dio] with no interceptors, sharing its transport and options.
  ///
  /// The token refresh and the replayed request must not recurse back through
  /// the auth interceptor.
  static Dio siblingOf(Dio dio) =>
      Dio(dio.options)..httpClientAdapter = dio.httpClientAdapter;

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _request(() => _dio.get<dynamic>(path, queryParameters: queryParameters));

  /// [idempotencyKey] guards reward-producing writes: the API treats a repeat
  /// of the same key as the same request, so a retry cannot pay out twice.
  Future<dynamic> post(String path, {Object? data, String? idempotencyKey}) =>
      _request(
        () => _dio.post<dynamic>(
          path,
          data: data,
          options: idempotencyKey == null
              ? null
              : Options(headers: {'Idempotency-Key': idempotencyKey}),
        ),
      );

  Future<dynamic> put(String path, {Object? data}) =>
      _request(() => _dio.put<dynamic>(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) =>
      _request(() => _dio.patch<dynamic>(path, data: data));

  Future<dynamic> delete(String path, {Object? data}) =>
      _request(() => _dio.delete<dynamic>(path, data: data));

  Future<dynamic> _request(Future<Response<dynamic>> Function() send) async {
    try {
      return unwrap(await send());
    } on DioException catch (e) {
      throw mapDioException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(AppExceptionKind.unknown, message: e.toString());
    }
  }

  /// Unwraps the API envelope, throwing when it reports a failure.
  static dynamic unwrap(Response<dynamic> response) {
    final body = response.data;
    final status = response.statusCode ?? 0;

    if (body is Map<String, dynamic> && body.containsKey('success')) {
      if (body['success'] == true) return body['data'];
      throw AppException(
        _kindFor(status, body['errorCode'] as String?),
        message: body['message'] as String?,
        statusCode: status,
        errorCode: body['errorCode'] as String?,
        fieldErrors: _fieldErrors(body),
      );
    }

    // Endpoints that answer without the envelope.
    if (status >= 200 && status < 300) return body;
    throw AppException(
      _kindFor(status, null),
      message: 'Unexpected response ($status)',
      statusCode: status,
    );
  }

  static AppExceptionKind _kindFor(int status, String? errorCode) {
    if (errorCode == ApiErrorCodes.invalidToken) {
      return AppExceptionKind.unauthorized;
    }
    return switch (status) {
      401 || 403 => AppExceptionKind.unauthorized,
      >= 500 => AppExceptionKind.server,
      >= 400 => AppExceptionKind.badRequest,
      _ => AppExceptionKind.unknown,
    };
  }

  /// The API reports validation problems as
  /// `"Validation failed: field: message, field2: message"`.
  static Map<String, String> _fieldErrors(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map) {
      return errors.map((k, v) => MapEntry('$k', '$v'));
    }
    final message = body['message'];
    if (body['errorCode'] != ApiErrorCodes.validationError ||
        message is! String ||
        !message.contains(':')) {
      return const {};
    }
    final result = <String, String>{};
    for (final part in message.split('Validation failed:').last.split(',')) {
      final bits = part.split(':');
      if (bits.length < 2) continue;
      result[bits.first.trim()] = bits.sublist(1).join(':').trim();
    }
    return result;
  }

  static AppException mapDioException(DioException e) => switch (e.type) {
    DioExceptionType.connectionError || DioExceptionType.connectionTimeout =>
      const AppException(AppExceptionKind.network),
    DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout =>
      const AppException(AppExceptionKind.timeout),
    DioExceptionType.badResponse => AppException(
      _kindFor(e.response?.statusCode ?? 0, null),
      message: e.message,
      statusCode: e.response?.statusCode,
    ),
    _ => AppException(AppExceptionKind.unknown, message: e.message),
  };
}
