import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_identity.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_store.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStoreProvider),
    ref.watch(deviceIdentityProvider),
  ),
);

/// Talks to the `01 Auth` endpoint group.
///
/// Every call that yields a session persists its tokens, so the interceptor
/// and the next app launch can pick them up.
class AuthRepository {
  AuthRepository(this._api, this._secureStore, this._device);

  final ApiClient _api;
  final SecureStore _secureStore;
  final DeviceIdentity _device;

  /// App version reported to the backend on login.
  static const String _appVersion = '1.0.0';

  /// `POST /auth/register` — the backend returns a session straight away,
  /// so there is no separate verification step before the user is signed in.
  Future<AuthSession> register({
    required String fullName,
    required String mobile,
    required String password,
    String countryCode = 'BD',
    String? email,
    String? referralCode,
  }) async {
    final data = await _api.post(
      '/auth/register',
      data: {
        'fullName': fullName,
        'countryCode': countryCode,
        'mobile': mobile,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
      },
    );
    return _persist(data);
  }

  /// `POST /auth/login`. [identifier] may be an email or a mobile number —
  /// the backend accepts either in the `email` field.
  Future<AuthSession> login({
    required String identifier,
    required String password,
    String? pushToken,
  }) async {
    final data = await _api.post(
      '/auth/login',
      data: {
        'email': identifier,
        'password': password,
        'deviceId': _device.id,
        'deviceName': _device.name,
        'platform': _device.platform,
        'appVersion': _appVersion,
        if (pushToken != null && pushToken.isNotEmpty) 'pushToken': pushToken,
      },
    );
    return _persist(data);
  }

  /// `GET /users/me` — used to restore a session on app start.
  Future<AuthUser> currentUser() async {
    final data = await _api.get('/users/me');
    final user = AuthUser.fromJson((data as Map).cast<String, dynamic>());
    await _secureStore.saveUser(user.toJson());
    return user;
  }

  /// The last profile seen, for restoring a session with no network.
  Future<AuthUser?> cachedUser() async {
    final json = await _secureStore.readUser();
    return json == null ? null : AuthUser.fromJson(json);
  }

  Future<({String? access, String? refresh})> storedTokens() async => (
    access: await _secureStore.readAccessToken(),
    refresh: await _secureStore.readRefreshToken(),
  );

  Future<void> clearSession() => _secureStore.clear();

  /// `POST /auth/forgot-password` — sends a 6-digit OTP.
  Future<void> requestPasswordOtp(String emailOrPhone) =>
      _api.post('/auth/forgot-password', data: {'emailOrPhone': emailOrPhone});

  /// `POST /auth/verify-otp`.
  Future<void> verifyOtp({required String emailOrPhone, required String otp}) =>
      _api.post(
        '/auth/verify-otp',
        data: {'emailOrPhone': emailOrPhone, 'otp': otp},
      );

  /// `POST /auth/reset-password` — [token] is the OTP the user received.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _api.post(
    '/auth/reset-password',
    data: {'token': token, 'newPassword': newPassword},
  );

  /// `POST /auth/logout` for this device only.
  Future<void> logout() async {
    final refreshToken = await _secureStore.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _api.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } finally {
      // The local session goes regardless of what the server says.
      await _secureStore.clear();
    }
  }

  Future<AuthSession> _persist(dynamic data) async {
    if (data is! Map) {
      throw StateError('Unexpected auth response: $data');
    }
    final session = AuthSession.fromJson(data.cast<String, dynamic>());
    await _secureStore.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    await _secureStore.saveUser(session.user.toJson());
    return session;
  }
}
