import 'package:flutter/material.dart';

/// Brand color tokens extracted from the Uparjon Figma file.
///
/// Keep this file as the single source of truth for raw color values —
/// widgets should consume colors via [Theme]/[ColorScheme] or these tokens,
/// never hard-code hex values.
abstract final class AppColors {
  // Brand
  static const Color gold = Color(0xFFFDD700);
  static const Color goldLight = Color(0xFFFEE79C);
  static const Color charcoal = Color(0xFF333132);
  static const Color gray = Color(0xFF6D6E71);
  static const Color grayLight = Color(0xFFA8AAAD);

  /// Deeper amber pair used by the onboarding accents and next button.
  static const Color amber = Color(0xFFF4A300);
  static const Color amberLight = Color(0xFFFFD54F);

  // Text
  static const Color ink = Color(0xFF112235);
  static const Color inkStrong = Color(0xFF20252C);
  static const Color slate = Color(0xFF667085);

  // Surfaces
  static const Color cream = Color(0xFFFBF6F3);
  static const Color creamLight = Color(0xFFFCF9F5);
  static const Color surface = Color(0xFFF9F9F9);
  static const Color white = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFCFD6DC);
  static const Color border = Color(0xFFE1E8EC);
  static const Color hint = Color(0xFF728B9E);
  static const Color link = Color(0xFFFE980C);

  // Semantic
  static const Color success = Color(0xFF2E9E5B);
  static const Color error = Color(0xFFD64545);

  /// Destructive actions in the menu (Figma "Log Out").
  static const Color danger = Color(0xFFE93C3C);
  static const Color warning = Color(0xFFE8A13D);
  static const Color info = Color(0xFF3B82C4);

  // Earning module accents (Figma "Uparjon", "Ad list", "Ad overview")
  /// Stat figures and the progress rings — same value as [link].
  static const Color orange = Color(0xFFFE980C);
  static const Color blue = Color(0xFF5C8DD3);
  static const Color blueTint = Color(0xFFF3F7FE);
  static const Color green = Color(0xFF0F9863);
  static const Color greenTint = Color(0xFFEFF6F2);

  /// Reward amounts ("+ ৳10.00").
  static const Color greenDeep = Color(0xFF005B3D);
  static const Color purple = Color(0xFFA16EE6);
  static const Color purpleTint = Color(0xFFF7F3FC);
  static const Color amberTint = Color(0xFFFDF7E9);
  static const Color lavenderTint = Color(0xFFF0F4FC);
  static const Color pendingChip = Color(0xFFFEDB82);
  static const Color dangerText = Color(0xFFDB3B44);

  /// Dimmed backdrop behind the overview and status popups.
  static const Color scrim = Color(0x66000000);

  /// Gradient used on primary CTAs (e.g. "Explore Uparjon").
  static const Gradient ctaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold],
  );

  /// Primary CTA gradient (auth screens, most buttons) — diagonal per Figma.
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [amberLight, amber],
  );

  /// Soft tinted fill used by secondary CTAs (e.g. "Guest Login").
  static const Gradient softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33FEDB82), Color(0x33FBEFD0)],
  );

  /// Gradient used on the onboarding next button and accent bar.
  static const Gradient amberGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [amber, amberLight],
  );
}
