import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';

/// Full-screen wait state (Figma V2: "Uparjon - Loading Advertisement",
/// "Loading Survey", "Loading Quiz").
class PreparingView extends StatelessWidget {
  const PreparingView({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustration = AppAssets.illustrationLoadingAd,
  });

  final String title;
  final String subtitle;
  final String illustration;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.creamLight,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(illustration, width: 160, height: 160),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
