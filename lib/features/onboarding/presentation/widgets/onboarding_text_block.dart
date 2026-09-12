import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Eyebrow + headline pair with the gold accent bar down the left edge.
class OnboardingTextBlock extends StatelessWidget {
  const OnboardingTextBlock({
    super.key,
    required this.eyebrow,
    required this.headline,
  });

  final String eyebrow;
  final String headline;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 9,
            decoration: BoxDecoration(
              gradient: AppColors.amberGradient,
              borderRadius: BorderRadius.circular(4.5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
