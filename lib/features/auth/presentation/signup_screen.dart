import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_circle_check.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/utils/validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Registration screen (Figma: "Sign Up").
///
/// Submitting sends an OTP; the account is created once it is verified.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      SnackbarService.showError('Please accept the Terms & Conditions.');
      return;
    }
    FocusScope.of(context).unfocus();

    // The API returns a session on success, so registration signs the user
    // straight in — there is no separate verification step.
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          fullName: _name.text.trim(),
          mobile: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    if (ok) context.goNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Sign Up',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _name,
                hint: 'Full Name (According to your NID)',
                icon: AppAssets.iconUser,
                textInputAction: TextInputAction.next,
                validator: Validators.name,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _phone,
                hint: 'Phone Number',
                icon: AppAssets.iconPhone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: Validators.phone,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _email,
                hint: 'Email',
                icon: AppAssets.iconEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _password,
                hint: 'Password',
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
        const SizedBox(height: 20),
        Row(
          children: [
            AppCircleCheck(
              value: _acceptedTerms,
              semanticLabel: 'I agree with the Terms and Conditions',
              onChanged: (v) => setState(() => _acceptedTerms = v),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                // TODO(legal): open the hosted Terms & Conditions page.
                onTap: () => SnackbarService.showInfo(
                  'Terms & Conditions are coming soon.',
                ),
                child: const Text.rich(
                  TextSpan(
                    text: 'I agree with the ',
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(
                          color: AppColors.link,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.link,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 14, color: AppColors.charcoal),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Sign Up', loading: busy, onPressed: _submit),
        const SizedBox(height: 28),
        const AuthDivider(),
        const SizedBox(height: 24),
        AuthFooterLink(
          question: 'Already have an account?',
          action: 'Login',
          onPressed: () => context.goNamed(Routes.login),
        ),
      ],
    );
  }
}
