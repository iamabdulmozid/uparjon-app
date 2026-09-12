import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_circle_check.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/utils/validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Login screen (Figma: "login").
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(identifier: _identifier.text.trim(), password: _password.text);
    if (!mounted) return;
    if (ok) context.goNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Login',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _identifier,
                hint: 'Phone Number or Email',
                icon: AppAssets.iconUser,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    Validators.required(v, field: 'Phone number or email'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _password,
                hint: 'Password',
                icon: AppAssets.iconLock,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: Validators.password,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        AppButton(label: 'Login', loading: busy, onPressed: _submit),
        const SizedBox(height: 20),
        Row(
          children: [
            AppCircleCheck(
              value: _rememberMe,
              semanticLabel: 'Remember me',
              onChanged: (v) => setState(() => _rememberMe = v),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Remember me',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: AppColors.charcoal),
              ),
            ),
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.pushNamed(Routes.forgotPassword),
                child: const Text(
                  'Forgot Password',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.link,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.link,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const AuthDivider(),
        const SizedBox(height: 24),
        AppButton(
          label: 'Guest Login',
          variant: AppButtonVariant.soft,
          // Guests browse without earning; the API gates reward actions.
          onPressed: busy ? null : () => context.goNamed(Routes.home),
        ),
        const SizedBox(height: 24),
        AuthFooterLink(
          question: "Don't have an account?",
          action: 'Sign Up',
          onPressed: () => context.goNamed(Routes.signup),
        ),
      ],
    );
  }
}
