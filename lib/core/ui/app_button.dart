import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

enum AppButtonVariant {
  /// Amber gradient CTA — the default across the app.
  primary,

  /// Lighter gold gradient used on the splash/welcome artwork.
  brand,

  /// Tinted, low-emphasis fill (e.g. "Guest Login").
  soft,
  outline,
  ghost,
}

/// Brand button — the workhorse of the internal UI kit.
///
/// Variants follow a shadcn-style API so new styles are added here, never
/// ad-hoc in screens.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.expanded = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Fills the available width (design default).
  final bool expanded;
  final bool loading;

  static const double _height = 51;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final effectiveOnPressed = enabled ? onPressed : null;

    final child = loading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.charcoal,
            ),
          )
        : Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          );

    final button = switch (variant) {
      AppButtonVariant.primary => _FilledButton(
        gradient: AppColors.primaryGradient,
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.brand => _FilledButton(
        gradient: AppColors.ctaGradient,
        height: 56,
        onPressed: effectiveOnPressed,
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 18),
          child: child,
        ),
      ),
      AppButtonVariant.soft => _FilledButton(
        gradient: AppColors.softGradient,
        border: const BorderSide(color: Color(0x66FFD54F)),
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(_height),
          side: const BorderSide(color: AppColors.amber, width: 1.5),
          foregroundColor: AppColors.charcoal,
          shape: const StadiumBorder(),
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(foregroundColor: AppColors.charcoal),
        child: child,
      ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({
    required this.child,
    required this.gradient,
    this.onPressed,
    this.border,
    this.height = AppButton._height,
  });

  final Widget child;
  final Gradient gradient;
  final VoidCallback? onPressed;
  final BorderSide? border;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);

    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: radius,
          border: border == null ? null : Border.fromBorderSide(border!),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Container(
              height: height,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
