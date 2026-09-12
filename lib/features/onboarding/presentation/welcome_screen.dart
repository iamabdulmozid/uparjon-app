import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/app_button.dart';

/// Welcome screen (Figma: "Spalsh 2") — the splash artwork with the logo
/// raised and the "Explore Uparjon" call to action.
///
/// The CTA opens the onboarding carousel.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: size.height * 0.19,
            left: -size.width * 0.022,
            right: -size.width * 0.022,
            child: Image.asset(
              AppAssets.splashBackground,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.35),
            child: SvgPicture.asset(AppAssets.logo, width: size.width * 0.52),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: AppButton(
                  label: 'Explore Uparjon',
                  variant: AppButtonVariant.brand,
                  onPressed: () => context.goNamed(Routes.onboarding),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
