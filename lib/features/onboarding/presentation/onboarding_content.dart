import '../../../core/constants/app_assets.dart';

/// One onboarding slide.
///
/// [headline] carries its line break from the design — the copy is written to
/// break after the first word rather than wrapping freely.
class OnboardingSlide {
  const OnboardingSlide({
    required this.illustration,
    required this.eyebrow,
    required this.headline,
  });

  final String illustration;
  final String eyebrow;
  final String headline;
}

/// The three slides, in order (Figma: "Onboarding Flow 01..03").
///
/// One slide per pillar of the product: earning today, freelancing next,
/// and business/e-commerce reach after that.
const List<OnboardingSlide> onboardingSlides = [
  OnboardingSlide(
    illustration: AppAssets.onboardingEarn,
    eyebrow: 'Earn Daily',
    headline: 'Rewards\nbeyond advertisements',
  ),
  OnboardingSlide(
    illustration: AppAssets.onboardingHire,
    eyebrow: 'Hire Experts',
    headline: 'Trusted\nprofessionals nearby',
  ),
  OnboardingSlide(
    illustration: AppAssets.onboardingGrow,
    eyebrow: 'Expand Business',
    headline: 'Reach\nyour ideal audience',
  ),
];
