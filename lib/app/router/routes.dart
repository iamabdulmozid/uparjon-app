/// Central route table. Navigate by name: `context.goNamed(Routes.login)`.
abstract final class Routes {
  static const String splash = 'splash';
  static const String splashPath = '/';

  static const String welcome = 'welcome';
  static const String welcomePath = '/welcome';

  static const String onboarding = 'onboarding';
  static const String onboardingPath = '/onboarding';

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String signup = 'signup';
  static const String signupPath = '/signup';

  static const String forgotPassword = 'forgot-password';
  static const String forgotPasswordPath = '/forgot-password';

  /// Takes a `contact` query parameter (phone or email).
  static const String otp = 'otp';
  static const String otpPath = '/otp';

  /// Takes `otp` and `contact` query parameters.
  static const String resetPassword = 'reset-password';
  static const String resetPasswordPath = '/reset-password';

  static const String home = 'home';
  static const String homePath = '/home';

  /// One earning category (`ads`, `surveys`, `quizzes`, `campaigns`) — the
  /// `kind` path parameter is an `EarnTaskKind.slug`.
  static const String earnList = 'earn-list';
  static const String earnListPath = '/earn/:kind';

  /// Earning content. Each takes an `id` path parameter.
  static const String watchAd = 'watch-ad';
  static const String watchAdPath = '/earn/ads/:id';

  static const String survey = 'survey';
  static const String surveyPath = '/earn/surveys/:id';

  static const String quiz = 'quiz';
  static const String quizPath = '/earn/quizzes/:id';

  static const String campaign = 'campaign';
  static const String campaignPath = '/earn/campaigns/:id';

  // Registered as features land: wallet, profile, menu...
}
