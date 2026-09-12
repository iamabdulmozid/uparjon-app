import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/failure.dart';
import '../../../core/media/timed_playback.dart';
import '../../../core/media/video_playback.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/earn_popup.dart';
import 'widgets/earn_task_card.dart';
import 'widgets/preparing_view.dart';

/// Watch-an-ad flow (Figma: "Preparing Advertisement" → "Watch Ad" →
/// "Verifying" → "Congratulation!" / "Wrong Answer!").
///
/// The video cannot be skipped — the only controls are play/pause and mute.
/// When it ends the view goes to `POST /mobile/ads/{id}/view`, which
/// re-checks the watched duration server-side and decides on the reward.
///
/// The design's post-video question is not built: `VideoAdDto` carries no
/// question, so there is nothing to ask yet. When the API exposes one it
/// slots in between [_Phase.watching] and [_Phase.verifying].
class WatchAdScreen extends ConsumerStatefulWidget {
  const WatchAdScreen({super.key, required this.adId});

  final String adId;

  @override
  ConsumerState<WatchAdScreen> createState() => _WatchAdScreenState();
}

enum _Phase { preparing, watching, verifying, result }

class _WatchAdScreenState extends ConsumerState<WatchAdScreen>
    with WidgetsBindingObserver {
  VideoAd? _ad;
  VideoPlayback? _playback;
  _Phase _phase = _Phase.preparing;
  String? _loadError;
  AdView? _result;
  Failure? _failure;
  VideoPlaybackState? _finalState;
  bool _popupHidden = false;
  bool _adopting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playback?.state.removeListener(_onPlayback);
    unawaited(_playback?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Time in the background is not watch time.
    if (state != AppLifecycleState.resumed) unawaited(_playback?.pause());
  }

  /// Takes the ad out of the feed once and keeps it: the feed is invalidated
  /// after the view is recorded, and this screen must not blank out then.
  void _adopt(VideoAd ad) {
    if (_ad != null) return;
    setState(() => _ad = ad);
    unawaited(_prepare(ad));
  }

  Future<void> _prepare(VideoAd ad) async {
    final url = Uri.tryParse(ad.videoUrl ?? '');
    final playback = url != null && url.hasScheme
        ? ref.read(videoPlaybackFactoryProvider)(url)
        : TimedPlayback(
            Duration(seconds: ad.duration ?? 0),
            surface: _NoVideoSurface(title: ad.title),
          );

    _playback?.state.removeListener(_onPlayback);
    unawaited(_playback?.dispose());
    _playback = playback;

    await playback.initialize();
    if (!mounted) return;

    final error = playback.state.value.error;
    setState(() {
      _loadError = error;
      if (error == null) _phase = _Phase.watching;
    });
    playback.state.addListener(_onPlayback);
    _onPlayback();
  }

  void _retry() {
    final ad = _ad;
    if (ad == null) return;
    setState(() {
      _loadError = null;
      _phase = _Phase.preparing;
    });
    unawaited(_prepare(ad));
  }

  void _onPlayback() {
    if (!mounted) return;
    final state = _playback!.state.value;
    if (state.completed && _phase == _Phase.watching) {
      unawaited(_verify(state));
      return;
    }
    setState(() {});
  }

  Future<void> _verify(VideoPlaybackState state) async {
    setState(() {
      _phase = _Phase.verifying;
      _finalState = state;
      _failure = null;
      _popupHidden = false;
    });
    final watched = math.max(
      state.position.inSeconds,
      state.duration.inSeconds,
    );
    try {
      final view = await ref
          .read(earnRepositoryProvider)
          .submitAdView(adId: widget.adId, watchedSeconds: watched);
      if (!mounted) return;
      setState(() {
        _result = view;
        _phase = _Phase.result;
        _popupHidden = false;
      });
      // The ad is spent — drop it from the feeds behind this screen.
      invalidateEarnFeeds(ref);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = Failure.from(error);
        _phase = _Phase.result;
        _popupHidden = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return _buildGate(context);

    final loadError = _loadError;
    final preparing = _phase == _Phase.preparing;
    final Widget body;
    if (preparing) {
      body = loadError == null
          ? const PreparingView(
              title: 'Preparing Advertisement',
              subtitle: 'Please wait a moment',
            )
          : EarnListState(message: loadError, onRetry: _retry);
    } else {
      body = _WatchBody(playback: _playback!);
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: preparing && loadError == null ? null : _appBar(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (_phase == _Phase.verifying && !_popupHidden)
            EarnPopup(
              illustration: AppAssets.illustrationVerifying,
              title: 'Verifying',
              message: 'Please wait while we verify your view',
              onClose: () => setState(() => _popupHidden = true),
            ),
          if (_phase == _Phase.result && !_popupHidden) _resultPopup(context),
        ],
      ),
    );
  }

  /// Finds the ad in the feed; shown until [_adopt] has run.
  Widget _buildGate(BuildContext context) {
    final feed = ref.watch(adsFeedProvider);
    final found = feed.value
        ?.where((candidate) => candidate.adId == widget.adId)
        .firstOrNull;
    if (found != null && !_adopting) {
      _adopting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _adopt(found);
      });
    }
    final missing = feed.hasValue && found == null;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: feed.hasError || missing ? _appBar(context) : null,
      body: feed.when(
        loading: () => const PreparingView(
          title: 'Preparing Advertisement',
          subtitle: 'Please wait a moment',
        ),
        error: (error, _) => EarnListState(
          message: error is Failure ? error.message : 'Could not load this ad.',
          onRetry: () => ref.invalidate(adsFeedProvider),
        ),
        data: (_) => found == null
            ? const EarnListState(message: 'This ad is no longer available.')
            : const PreparingView(
                title: 'Preparing Advertisement',
                subtitle: 'Please wait a moment',
              ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) => AppBar(
    backgroundColor: AppColors.creamLight,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    title: const Text(
      'Watch Ad',
      style: TextStyle(fontSize: 18, color: AppColors.ink),
    ),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      color: AppColors.ink,
      onPressed: () => context.pop(),
    ),
  );

  Widget _resultPopup(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      // Transport problems are worth another go: the idempotency key makes
      // the retry safe. A domain refusal is final.
      final retryable = failure is NetworkFailure || failure is ServerFailure;
      return EarnPopup(
        illustration: AppAssets.illustrationNotRewarded,
        title: 'Could not verify',
        message: failure.message,
        actionLabel: retryable ? 'Try again' : 'Continue',
        onAction: retryable
            ? () => unawaited(_verify(_finalState!))
            : () => context.pop(),
        onClose: () => context.pop(),
      );
    }

    final rewarded = _result?.isRewarded ?? false;
    return EarnPopup(
      illustration: rewarded
          ? AppAssets.illustrationCongratulations
          : AppAssets.illustrationNotRewarded,
      title: rewarded ? 'Congratulation!' : 'Not rewarded',
      message: rewarded
          ? 'You watched the full ad. Your reward will be added to your '
                'wallet after verification.'
          : "This view didn't qualify for a reward this time.",
      actionLabel: 'Continue',
      onAction: () => context.pop(),
      onClose: () => context.pop(),
    );
  }
}

class _WatchBody extends StatelessWidget {
  const _WatchBody({required this.playback});

  final VideoPlayback playback;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        children: [
          _Player(playback: playback),
          const SizedBox(height: 20),
          const Text(
            'Watch till the end',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Watch the full video without skipping. Your reward is verified '
            'as soon as it ends.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

/// The player surface with the design's controls: a centre play/pause
/// button, the clock, and mute. Deliberately no seek bar — skipping ahead
/// would forfeit the reward anyway.
class _Player extends StatelessWidget {
  const _Player({required this.playback});

  final VideoPlayback playback;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlaybackState>(
      valueListenable: playback.state,
      builder: (context, state, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: state.aspectRatio.clamp(0.75, 2.4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: playback.buildSurface(context),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (state.playing) {
                      playback.pause();
                    } else {
                      playback.play();
                    }
                  },
                  child: Center(
                    child: state.playing
                        ? const SizedBox.shrink()
                        : _PlayButton(completed: state.completed),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Text(
                    '${Formatters.clock(state.position)} / '
                    '${Formatters.clock(state.duration)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 0,
                  child: IconButton(
                    tooltip: state.muted ? 'Unmute' : 'Mute',
                    icon: Icon(
                      state.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    onPressed: () => playback.setMuted(!state.muted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: completed ? 'Finished' : 'Play',
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xCC3C3C43),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          completed ? Icons.check_rounded : Icons.play_arrow_rounded,
          size: 34,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Stand-in frames for an ad that arrived without a video URL.
class _NoVideoSurface extends StatelessWidget {
  const _NoVideoSurface({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.charcoal,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 28,
                color: Colors.white54,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Preview unavailable — the timer still counts your watch.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
