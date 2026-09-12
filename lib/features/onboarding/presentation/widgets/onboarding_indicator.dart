import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Page indicator: the active slide is a rounded pill, the rest are dots.
class OnboardingIndicator extends StatelessWidget {
  const OnboardingIndicator({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  static const double _dotSize = 10;
  static const double _activeWidth = 20;
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: i == activeIndex ? _activeWidth : _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              color: i == activeIndex ? AppColors.amber : AppColors.divider,
              borderRadius: BorderRadius.circular(_dotSize / 2),
            ),
          ),
        ],
      ],
    );
  }
}
