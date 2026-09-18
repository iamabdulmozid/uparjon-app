import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/ui/app_button.dart';

/// Illustrated status card over a dimmed screen (Figma: "Verifying",
/// "Congratulation!", "Wrong Answer!", and V2's "Success" / "Alert").
///
/// Drawn inside the screen's own [Stack] rather than pushed as a route, so
/// the screen keeps control of its phases: a request that finishes after the
/// user closed the popup simply shows the next one.
class EarnPopup extends StatelessWidget {
  const EarnPopup({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionVariant = AppButtonVariant.primary,
    this.secondaryLabel,
    this.onSecondary,
    this.onClose,
  });

  final String illustration;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppButtonVariant actionVariant;

  /// Low-emphasis button drawn left of the action (V2 "Alert": Back).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.scrim,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: AppColors.creamLight,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: onClose == null
                            ? const SizedBox(height: 40)
                            : IconButton(
                                onPressed: onClose,
                                tooltip: 'Close',
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.ink,
                                ),
                              ),
                      ),
                      Image.asset(illustration, width: 160, height: 160),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.slate,
                        ),
                      ),
                      if (actionLabel != null) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            if (secondaryLabel != null) ...[
                              SizedBox(
                                width: 100,
                                child: AppButton(
                                  label: secondaryLabel!,
                                  variant: AppButtonVariant.soft,
                                  dense: true,
                                  onPressed: onSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: AppButton(
                                label: actionLabel!,
                                variant: actionVariant,
                                dense: true,
                                onPressed: onAction,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
