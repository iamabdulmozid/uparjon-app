import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/error/failure.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';

/// Watch-an-ad flow (Figma: "Preparing Advertisement" → "Watch Ad").
///
/// The reward is only claimed once the required watch time has elapsed; the
/// server re-checks the duration, so leaving early simply forfeits it.
class WatchAdScreen extends ConsumerStatefulWidget {
  const WatchAdScreen({super.key, required this.adId});

  final String adId;

  @override
  ConsumerState<WatchAdScreen> createState() => _WatchAdScreenState();
}

class _WatchAdScreenState extends ConsumerState<WatchAdScreen> {
  Timer? _ticker;
  int _watched = 0;
  bool _submitting = false;
  AdView? _result;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startWatching(VideoAd ad) {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _watched++);
      if (_watched >= (ad.duration ?? 0)) _ticker?.cancel();
    });
  }

  Future<void> _claim(VideoAd ad) async {
    setState(() => _submitting = true);
    try {
      final view = await ref
          .read(earnRepositoryProvider)
          .submitAdView(adId: ad.adId, watchedSeconds: _watched);
      if (!mounted) return;
      setState(() => _result = view);

      // The ad is spent — drop it from the feeds behind this screen.
      invalidateEarnFeeds(ref);
      SnackbarService.showSuccess(
        view.isRewarded
            ? 'Reward earned! It will appear in your wallet shortly.'
            : 'View recorded.',
      );
    } catch (error) {
      if (!mounted) return;
      SnackbarService.showFailure(Failure.from(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(adsFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Watch Ad',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
      ),
      body: feed.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (error, _) => Center(
          child: Text(
            error is Failure ? error.message : 'Could not load this ad.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate),
          ),
        ),
        data: (ads) {
          final ad = ads.where((a) => a.adId == widget.adId).firstOrNull;
          if (ad == null) {
            return const Center(
              child: Text(
                'This ad is no longer available.',
                style: TextStyle(color: AppColors.slate),
              ),
            );
          }
          return _AdBody(
            ad: ad,
            watched: _watched,
            submitting: _submitting,
            result: _result,
            onStart: () => _startWatching(ad),
            onClaim: () => _claim(ad),
            onDone: () => context.pop(),
          );
        },
      ),
    );
  }
}

class _AdBody extends StatelessWidget {
  const _AdBody({
    required this.ad,
    required this.watched,
    required this.submitting,
    required this.result,
    required this.onStart,
    required this.onClaim,
    required this.onDone,
  });

  final VideoAd ad;
  final int watched;
  final bool submitting;
  final AdView? result;
  final VoidCallback onStart;
  final VoidCallback onClaim;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final required = ad.duration ?? 0;
    final started = watched > 0;
    final finished = required > 0 && watched >= required;
    final progress = required == 0 ? 0.0 : (watched / required).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          // TODO(media): swap for the real player once video_player is added;
          // the countdown already mirrors the server's duration check.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  started ? Icons.play_circle_fill : Icons.play_circle_outline,
                  size: 64,
                  color: AppColors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            ad.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (ad.reward != null)
            Text(
              'Earn ${Formatters.taka(ad.reward!)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF005B3D),
              ),
            ),
          const SizedBox(height: 28),
          if (result == null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.amber),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              finished
                  ? 'Finished — claim your reward'
                  : started
                  ? '$watched of $required seconds watched'
                  : 'Watch $required seconds to earn',
              style: const TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 28),
            if (!started)
              AppButton(label: 'Start Watching', onPressed: onStart)
            else
              AppButton(
                label: 'Claim Reward',
                loading: submitting,
                onPressed: finished ? onClaim : null,
              ),
          ] else ...[
            Icon(
              result!.isRewarded ? Icons.check_circle : Icons.info_outline,
              size: 56,
              color: result!.isRewarded ? AppColors.success : AppColors.slate,
            ),
            const SizedBox(height: 12),
            Text(
              result!.isRewarded
                  ? 'Reward on its way'
                  : 'View recorded (${result!.status})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rewards are released after a quick fraud check.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.slate),
            ),
            const SizedBox(height: 28),
            AppButton(label: 'Done', onPressed: onDone),
          ],
        ],
      ),
    );
  }
}
