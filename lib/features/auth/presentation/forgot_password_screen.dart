import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/utils/validators.dart';
import 'password_reset_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Step 1 of the password reset: ask the backend to send an OTP.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final contact = _contact.text.trim();
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .requestOtp(contact);
    if (!mounted || !ok) return;

    context.pushNamed(Routes.otp, queryParameters: {'contact': contact});
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(passwordResetControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Forgot Password',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Text(
            'Enter your phone number or email and we will send you a '
            '6 digit code to reset your password.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF667085),
            ),
          ),
        ),
        Form(
          key: _formKey,
          child: AppTextField(
            controller: _contact,
            hint: 'Phone Number or Email',
            icon: AppAssets.iconUser,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                Validators.required(v, field: 'Phone number or email'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 32),
        AppButton(label: 'Send Code', loading: busy, onPressed: _submit),
      ],
    );
  }
}
