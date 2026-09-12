import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/earn/presentation/campaign_screen.dart';
import '../../features/earn/presentation/earn_task_kind.dart';
import '../../features/earn/presentation/quiz_screen.dart';
import '../../features/earn/presentation/survey_screen.dart';
import '../../features/earn/presentation/task_list_screen.dart';
import '../../features/earn/presentation/watch_ad_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../shell/app_shell.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splashPath,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: Routes.splashPath,
        name: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcomePath,
        name: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.onboardingPath,
        name: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.loginPath,
        name: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signupPath,
        name: Routes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: Routes.forgotPasswordPath,
        name: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.otpPath,
        name: Routes.otp,
        builder: (context, state) =>
            OtpScreen(emailOrPhone: state.uri.queryParameters['contact'] ?? ''),
      ),
      GoRoute(
        path: Routes.resetPasswordPath,
        name: Routes.resetPassword,
        builder: (context, state) =>
            ResetPasswordScreen(otp: state.uri.queryParameters['otp'] ?? ''),
      ),
      GoRoute(
        path: Routes.homePath,
        name: Routes.home,
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: Routes.earnListPath,
        name: Routes.earnList,
        builder: (context, state) => TaskListScreen(
          kind:
              EarnTaskKind.fromSlug(state.pathParameters['kind'] ?? '') ??
              EarnTaskKind.ads,
        ),
      ),
      GoRoute(
        path: Routes.watchAdPath,
        name: Routes.watchAd,
        builder: (context, state) =>
            WatchAdScreen(adId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.surveyPath,
        name: Routes.survey,
        builder: (context, state) =>
            SurveyScreen(surveyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.quizPath,
        name: Routes.quiz,
        builder: (context, state) =>
            QuizScreen(quizId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.campaignPath,
        name: Routes.campaign,
        builder: (context, state) =>
            CampaignScreen(campaignId: state.pathParameters['id']!),
      ),
    ],
    redirect: (context, state) {
      // Guard the signed-in area. Splash owns the first routing decision, so
      // it is left alone while the session is still being restored.
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null;

      final signedIn = auth.value != null;
      final path = state.matchedLocation;
      const guarded = [Routes.homePath, '/earn'];
      if (!signedIn && guarded.any(path.startsWith)) {
        return Routes.loginPath;
      }
      return null;
    },
  );
});
