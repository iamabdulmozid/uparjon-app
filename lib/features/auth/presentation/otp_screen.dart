import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/utils/validators.dart';
import 'password_reset_controller.dart';
import 'widgets/otp_input.dart';

/// OTP verification (Figma: "OTP 1/2").
///
/// The backend signs users in directly at registration, so this screen serves
/// the forgot-password flow: `/auth/forgot-password` sent a 6-digit code,
/// this verifies it and hands off to setting a new password.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.emailOrPhone});

  final String emailOrPhone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  String _code = '';
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .requestOtp(widget.emailOrPhone);
    if (!mounted || !ok) return;
    SnackbarService.showSuccess('We sent you a new code.');
    _startCountdown();
  }

  Future<void> _submit() async {
    if (_code.length != _codeLength) {
      SnackbarService.showError('Enter the $_codeLength digit code.');
      return;
    }
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .verifyOtp(emailOrPhone: widget.emailOrPhone, otp: _code);
    if (!mounted || !ok) return;

    context.pushNamed(
      Routes.resetPassword,
      queryParameters: {'otp': _code, 'contact': widget.emailOrPhone},
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(passwordResetControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Verify Your Code',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
          child: Column(
            children: [
              Image.asset(AppAssets.otpIllustration, width: 200, height: 200),
              const SizedBox(height: 32),
              Text(
                "We've sent a $_codeLength digit OTP to:\n"
                '${Validators.maskContact(widget.emailOrPhone)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Enter your OTP',
                style: TextStyle(fontSize: 20, color: AppColors.hint),
              ),
              const SizedBox(height: 24),
              OtpInput(
                length: _codeLength,
                onChanged: (v) => setState(() => _code = v),
                onCompleted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              _ResendRow(secondsLeft: _secondsLeft, onResend: _resend),
              const SizedBox(height: 48),
              AppButton(label: 'Next', loading: busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsLeft, required this.onResend});

  final int secondsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft == 0) {
      return GestureDetector(
        onTap: onResend,
        child: const Text(
          'Resend code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.link,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(
        text: 'Resend in ',
        style: const TextStyle(fontSize: 14, color: AppColors.slate),
        children: [
          TextSpan(
            text: '${secondsLeft}s',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.amberLight,
            ),
          ),
        ],
      ),
    );
  }
}
