import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/presentation/auth_controller.dart';

/// Splash screen (Figma: "Spalsh").
///
/// Cream background, watercolor cityscape artwork anchored to the bottom of
/// the screen, brand logo fading in at the center. After [_minimumDuration]
/// the app routes onward.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Keeps the brand visible long enough to register, short enough not to annoy.
  static const Duration _minimumDuration = Duration(milliseconds: 2500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    final onboardingDone = ref.read(localStoreProvider).onboardingDone;

    // Start the clock first, then restore any stored session while the brand
    // is on screen; awaiting both keeps the splash up for at least the
    // minimum without ever cutting the session restore short.
    final minimumElapsed = Future<void>.delayed(_minimumDuration);
    final session = await ref.read(authControllerProvider.future);
    await minimumElapsed;
    if (!mounted) return;

    if (session != null) {
      context.goNamed(Routes.home);
    } else {
      context.goNamed(onboardingDone ? Routes.login : Routes.welcome);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashBackground(),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: SvgPicture.asset(
                  AppAssets.logo,
                  width: size.width * 0.52,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Watercolor cityscape artwork, positioned as in Figma: starting ~19% from
/// the top, slightly wider than the screen, overflowing past the bottom edge.
class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Positioned(
      top: size.height * 0.19,
      left: -size.width * 0.022,
      right: -size.width * 0.022,
      child: Image.asset(
        AppAssets.splashBackground,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
