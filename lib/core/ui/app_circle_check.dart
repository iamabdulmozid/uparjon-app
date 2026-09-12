import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Circular single toggle used for "Remember me" and the terms checkbox
/// (Figma draws a 19pt ring rather than a square checkbox).
class AppCircleCheck extends StatelessWidget {
  const AppCircleCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: semanticLabel,
      child: InkWell(
        onTap: () => onChanged(!value),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.amber : Colors.transparent,
              border: Border.all(
                color: value ? AppColors.amber : AppColors.slate,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
