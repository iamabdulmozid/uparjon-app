import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../error/app_exception.dart';
import '../../storage/secure_store.dart';
import '../api_client.dart';

/// Attaches the bearer token, and refreshes it once when the API rejects it.
///
/// Access tokens live 15 minutes, refresh tokens 30 days. Concurrent 401s
/// share a single refresh call so a burst of requests cannot rotate the
/// refresh token several times over.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref, this._dio);

  final Ref _ref;

  /// The client this interceptor is attached to — cloned (without
  /// interceptors) for the refresh call and the replay.
  final Dio _dio;

  /// In-flight refresh, shared by every request that hits a 401 at once.
  Future<_RefreshResult>? _refreshCall;

  SecureStore get _store => _ref.read(secureStoreProvider);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _store.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_isExpiredToken(response) ||
        response.requestOptions.extra['retried'] == true) {
      handler.next(response);
      return;
    }

    final result = await _refreshOnce();
    final token = result.token;

    if (token == null) {
      // Only drop the session when the server actually refused the refresh.
      // If it simply could not be reached (offline, timeout), the tokens are
      // still good and must survive for the next launch.
      if (result.rejected) await _store.clear();
      handler.next(response);
      return;
    }

    try {
      handler.resolve(await _retry(response.requestOptions, token));
    } on DioException catch (e) {
      handler.next(e.response ?? response);
    }
  }

  /// Any 401 means the bearer token was rejected, so it is worth one refresh —
  /// except a failed sign-in, where there is nothing to refresh.
  ///
  /// The code is deliberately not matched against a fixed list: staging
  /// answers an expired token with `UNAUTHORIZED` while the handover docs
  /// promise `INVALID_TOKEN`, and either must trigger the refresh.
  bool _isExpiredToken(Response<dynamic> response) {
    if (response.requestOptions.extra['skipAuth'] == true) return false;
    if (response.statusCode != 401) return false;

    final body = response.data;
    if (body is! Map) return true;
    final code = body['errorCode'];
    return code != ApiErrorCodes.badCredentials &&
        code != ApiErrorCodes.invalidCredentials;
  }

  Future<_RefreshResult> _refreshOnce() =>
      _refreshCall ??= _refresh().whenComplete(() => _refreshCall = null);

  Future<_RefreshResult> _refresh() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return const _RefreshResult.rejected();
    }

    try {
      // Sibling client: refreshing must not recurse through this interceptor.
      final response = await ApiClient.siblingOf(_dio)
          .post<dynamic>('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = ApiClient.unwrap(response);
      if (data is! Map<String, dynamic>) return const _RefreshResult.rejected();

      final access = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String? ?? refreshToken;
      if (access == null || access.isEmpty) {
        return const _RefreshResult.rejected();
      }

      await _store.saveTokens(accessToken: access, refreshToken: refresh);
      return _RefreshResult.refreshed(access);
    } on AppException catch (e) {
      return _resultFor(e.kind);
    } on DioException catch (e) {
      return _resultFor(ApiClient.mapDioException(e).kind);
    } catch (_) {
      // Unknown cause — assume the session is still good rather than
      // signing the user out on a guess.
      return const _RefreshResult.unreachable();
    }
  }

  static _RefreshResult _resultFor(AppExceptionKind kind) =>
      kind == AppExceptionKind.network || kind == AppExceptionKind.timeout
      ? const _RefreshResult.unreachable()
      : const _RefreshResult.rejected();

  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    return ApiClient.siblingOf(_dio).fetch<dynamic>(
      options.copyWith(
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
        extra: {...options.extra, 'retried': true},
      ),
    );
  }
}

/// Outcome of a token refresh: renewed, refused by the server, or the server
/// could not be reached at all. Only a refusal should end the session.
class _RefreshResult {
  const _RefreshResult.refreshed(this.token) : rejected = false;
  const _RefreshResult.rejected() : token = null, rejected = true;
  const _RefreshResult.unreachable() : token = null, rejected = false;

  final String? token;
  final bool rejected;
}
