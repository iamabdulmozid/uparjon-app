import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/utils/validators.dart';
import 'password_reset_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Step 3 of the password reset: choose a new password using the verified OTP.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.otp});

  /// The verified code, passed to `/auth/reset-password` as `token`.
  final String otp;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .resetPassword(otp: widget.otp, newPassword: _password.text);
    if (!mounted || !ok) return;

    SnackbarService.showSuccess('Password updated. Please log in.');
    context.goNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(passwordResetControllerProvider).isLoading;

    return AuthScaffold(
      title: 'New Password',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _password,
                hint: 'New Password',
                icon: AppAssets.iconLock,
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _confirmPassword,
                hint: 'Confirm Password',
                icon: AppAssets.iconLock,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        AppButton(label: 'Save Password', loading: busy, onPressed: _submit),
      ],
    );
  }
}
