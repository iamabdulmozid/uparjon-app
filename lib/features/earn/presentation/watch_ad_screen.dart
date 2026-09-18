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
import '../../../core/ui/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/earn_popup.dart';
import 'widgets/earn_task_card.dart';
import 'widgets/preparing_view.dart';
import 'widgets/question_scaffold.dart';

/// Watch-an-ad flow (Figma V2: "Loading Advertisement" → "Watch Ad" →
/// question → "Verifying" → "Congratulation!" / "Wrong Answer!").
///
/// The video cannot be skipped — the only controls are play/pause and mute.
/// When it ends the view goes to `POST /mobile/ads/{id}/view`, which
/// re-checks the watched duration server-side and decides on the reward.
///
/// The post-video question ([_Phase.question]) only appears for ads that
/// carry one ([VideoAd.question]). `VideoAdDto` has none yet, so today every
/// ad goes straight from the video to verification.
class WatchAdScreen extends ConsumerStatefulWidget {
  const WatchAdScreen({super.key, required this.adId});

  final String adId;

  @override
  ConsumerState<WatchAdScreen> createState() => _WatchAdScreenState();
}

enum _Phase { preparing, watching, question, verifying, result }

class _WatchAdScreenState extends ConsumerState<WatchAdScreen>
    with WidgetsBindingObserver {
  VideoAd? _ad;
  VideoPlayback? _playback;
  _Phase _phase = _Phase.preparing;
  String? _loadError;
  AdView? _result;
  Failure? _failure;
  VideoPlaybackState? _finalState;

  /// Option picked for the ad's question; null for ads without one.
  String? _answer;
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
      if (_ad?.question != null) {
        setState(() {
          _phase = _Phase.question;
          _finalState = state;
        });
      } else {
        unawaited(_verify(state));
      }
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
          .submitAdView(
            adId: widget.adId,
            watchedSeconds: watched,
            answerOptionId: _answer,
          );
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
    final question = ad.question;
    final Widget body;
    if (preparing) {
      body = loadError == null
          ? const PreparingView(
              title: 'Loading Advertisement',
              subtitle: 'Please wait a moment',
            )
          : EarnListState(message: loadError, onRetry: _retry);
    } else if (question != null && _phase != _Phase.watching) {
      // Stays behind the Verifying/result popups once submitted.
      body = _AdQuestionBody(
        question: question,
        selected: _answer,
        enabled: _phase == _Phase.question,
        onSelect: (id) => setState(() => _answer = id),
        onBack: () => context.pop(),
        onSubmit: () => unawaited(_verify(_finalState!)),
      );
    } else {
      body = _WatchBody(playback: _playback!, hasQuestion: question != null);
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
              message: _answer == null
                  ? 'Please wait while we verify your view'
                  : 'Please wait while we verify your answer',
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
          title: 'Loading Advertisement',
          subtitle: 'Please wait a moment',
        ),
        error: (error, _) => EarnListState(
          message: error is Failure ? error.message : 'Could not load this ad.',
          onRetry: () => ref.invalidate(adsFeedProvider),
        ),
        data: (_) => found == null
            ? const EarnListState(message: 'This ad is no longer available.')
            : const PreparingView(
                title: 'Loading Advertisement',
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
    final answered = _answer != null;
    return EarnPopup(
      illustration: rewarded
          ? AppAssets.illustrationCongratulations
          : AppAssets.illustrationNotRewarded,
      title: rewarded
          ? 'Congratulation!'
          : answered
          ? 'Wrong Answer!'
          : 'Not rewarded',
      message: switch ((rewarded, answered)) {
        (true, true) =>
          'Your answer is correct. Your reward will be added to your wallet',
        (true, false) =>
          'You watched the full ad. Your reward will be added to your '
              'wallet after verification.',
        (false, true) =>
          'Your answer is not correct. You didn’t earn the reward this time.',
        (false, false) => "This view didn't qualify for a reward this time.",
      },
      actionLabel: 'Continue',
      onAction: () => context.pop(),
      onClose: () => context.pop(),
    );
  }
}

class _WatchBody extends StatelessWidget {
  const _WatchBody({required this.playback, required this.hasQuestion});

  final VideoPlayback playback;
  final bool hasQuestion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        children: [
          _Player(playback: playback),
          const SizedBox(height: 16),
          const Text(
            'Watch till the end',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuestion
                ? 'After the video, a question will appear. To earn the '
                      'reward you need to answer the question correctly.'
                : 'Watch the full video without skipping. Your reward is '
                      'verified as soon as it ends.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

/// The post-video question (Figma V2 "Uparjon - Watch Ad", Component 19):
/// one answer, then Submit. Back leaves without claiming the reward.
class _AdQuestionBody extends StatelessWidget {
  const _AdQuestionBody({
    required this.question,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onBack,
    required this.onSubmit,
  });

  final AdQuestion question;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),
                for (final option in question.options)
                  ChoiceTile(
                    label: option.text,
                    selected: selected == option.id,
                    onTap: () {
                      if (enabled) onSelect(option.id);
                    },
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.soft,
                    onPressed: enabled ? onBack : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Submit',
                    onPressed: enabled && selected != null ? onSubmit : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
        width: 60,
        height: 60,
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
