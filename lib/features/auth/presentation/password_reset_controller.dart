import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../data/auth_repository.dart';

/// Drives the forgot-password OTP flow:
/// request OTP → verify OTP → set a new password.
class PasswordResetController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> requestOtp(String emailOrPhone) =>
      _run(() => _repo.requestPasswordOtp(emailOrPhone));

  Future<bool> verifyOtp({required String emailOrPhone, required String otp}) =>
      _run(() => _repo.verifyOtp(emailOrPhone: emailOrPhone, otp: otp));

  Future<bool> resetPassword({
    required String otp,
    required String newPassword,
  }) => _run(() => _repo.resetPassword(token: otp, newPassword: newPassword));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(Failure.from(error), stackTrace);
      return false;
    }
  }
}

final passwordResetControllerProvider =
    AsyncNotifierProvider<PasswordResetController, void>(
      PasswordResetController.new,
    );
