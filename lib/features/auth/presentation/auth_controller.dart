import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/failure.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

/// Holds the signed-in session for the whole app.
///
/// `null` data means signed out. [build] restores a session from stored
/// tokens, so a returning user skips login.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final tokens = await _tokensOrNull();
    final access = tokens?.access;
    if (access == null || access.isEmpty) return null;

    final cached = await _repo.cachedUser();

    try {
      // Confirms the token is still valid and refreshes the profile; the
      // interceptor silently renews an expired access token first.
      final user = await _repo.currentUser();
      return AuthSession(
        user: user,
        accessToken: access,
        refreshToken: tokens?.refresh ?? '',
      );
    } on AppException catch (e) {
      // Only the server rejecting the token ends a session. A network
      // problem — offline, timeout, a 5xx — must never log someone out, so
      // the stored session is kept and the cached profile is used instead.
      if (e.kind == AppExceptionKind.unauthorized) {
        await _repo.clearSession();
        return null;
      }
      return AuthSession(
        user: cached ?? const AuthUser(id: '', fullName: ''),
        accessToken: access,
        refreshToken: tokens?.refresh ?? '',
      );
    } catch (_) {
      // Anything unexpected (including unreadable storage) is treated the
      // same way: keep the user signed in rather than losing their session.
      return AuthSession(
        user: cached ?? const AuthUser(id: '', fullName: ''),
        accessToken: access,
        refreshToken: tokens?.refresh ?? '',
      );
    }
  }

  /// Reads the stored tokens, tolerating storage that cannot be read.
  Future<({String? access, String? refresh})?> _tokensOrNull() async {
    try {
      return await _repo.storedTokens();
    } catch (_) {
      return null;
    }
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  bool get isSignedIn => state.value != null;

  Future<bool> login({required String identifier, required String password}) =>
      _run(() => _repo.login(identifier: identifier, password: password));

  /// Registration signs the user straight in — the API returns a session.
  Future<bool> register({
    required String fullName,
    required String mobile,
    required String password,
    String? email,
    String? referralCode,
  }) => _run(
    () => _repo.register(
      fullName: fullName,
      mobile: mobile,
      password: password,
      email: email,
      referralCode: referralCode,
    ),
  );

  /// Signs out. This never fails from the user's point of view: the local
  /// session is dropped even if revoking it server-side did not work, so a
  /// failing API can't strand someone in a signed-in shell with no tokens.
  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // Already logged by the client; nothing actionable for the user.
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  /// Runs an auth call, mapping failures into [state]. Returns whether it won.
  Future<bool> _run(Future<AuthSession> Function() action) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await action());
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(Failure.from(error), stackTrace);
      return false;
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// Convenience for widgets that only care whether someone is signed in.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).value != null,
);
