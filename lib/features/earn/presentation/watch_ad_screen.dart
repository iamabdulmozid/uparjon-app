import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/failure.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/media/timed_playback.dart';
import '../../../core/media/video_playback.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ids.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/answer_input.dart';
import 'widgets/earn_popup.dart';
import 'widgets/preparing_view.dart';

/// Watch-an-ad flow (Figma V3 "Watch Ad": media → question → "Verifying" →
/// "Congratulation!" / "Wrong Answer!"), per
/// `docs/mobile-flutter-media-quiz-integration-guide.md`.
///
/// The media cannot be skipped — the only controls are play/pause and mute.
/// When it ends, `POST /mobile/ads/{id}/view` records the watch, and the
/// server re-checks the duration. After that:
///
/// * an ad without questions is done — the view itself claims the reward;
/// * an ad with questions ([VideoAd.questions], from `GET /ads/{id}`) walks
///   them one at a time, then submits the answers for grading. The view has
///   to be recorded first: the server refuses answers without it.
class WatchAdScreen extends ConsumerStatefulWidget {
  const WatchAdScreen({super.key, required this.adId});

  final String adId;

  @override
  ConsumerState<WatchAdScreen> createState() => _WatchAdScreenState();
}

enum _Phase { preparing, watching, recording, question, verifying, result }

class _WatchAdScreenState extends ConsumerState<WatchAdScreen>
    with WidgetsBindingObserver {
  VideoAd? _ad;
  VideoPlayback? _playback;
  _Phase _phase = _Phase.preparing;
  String? _loadError;
  VideoPlaybackState? _finalState;

  /// Outcome of the view alone — set for ads without questions, or when the
  /// server refused the view outright.
  AdView? _result;

  /// Outcome of the answers.
  AdAssessment? _assessment;
  Failure? _failure;

  /// Repeats whichever request produced [_failure].
  VoidCallback? _retry;

  /// One key per request the user may retry, so a retry after a dropped
  /// connection is the same request to the server and cannot pay twice.
  String? _viewKey;
  String? _answersKey;

  /// The view is recorded, so the questions may be answered.
  bool _questionsOpen = false;
  int _index = 0;
  final Map<String, SurveyAnswer> _answers = {};

  /// Graded submissions so far, against [VideoAd.maxAttempts].
  int _attempts = 0;
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

  /// Takes the ad once and keeps it: the feed is invalidated after the view
  /// is recorded, and this screen must not blank out then.
  void _adopt(VideoAd ad) {
    if (_ad != null) return;
    setState(() => _ad = ad);
    unawaited(_prepare(ad));
  }

  Future<void> _prepare(VideoAd ad) async {
    final url = Uri.tryParse(ad.videoUrl ?? '');
    final length = Duration(seconds: ad.duration ?? 0);
    // Stills and GIFs have no clock of their own, so a timer stands in for
    // the video's — the watch rule is the same.
    final playback = url == null || !url.hasScheme
        ? TimedPlayback(length, surface: _NoVideoSurface(title: ad.title))
        : ad.isImage
        ? TimedPlayback(
            length,
            surface: _ImageSurface(url: url.toString(), title: ad.title),
          )
        : ref.read(videoPlaybackFactoryProvider)(url);

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

  void _reload() {
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
      _finalState = state;
      unawaited(_ad!.hasQuestions ? _recordView() : _claimView());
      return;
    }
    setState(() {});
  }

  int get _watchedSeconds {
    final state = _finalState!;
    return math.max(state.position.inSeconds, state.duration.inSeconds);
  }

  Future<AdView> _postView() => ref
      .read(earnRepositoryProvider)
      .submitAdView(
        adId: widget.adId,
        watchedSeconds: _watchedSeconds,
        idempotencyKey: _viewKey ??= Ids.newId(),
      );

  /// Ad without questions: the view is the whole task.
  Future<void> _claimView() async {
    _enter(_Phase.verifying);
    try {
      final view = await _postView();
      if (!mounted) return;
      _finish(view: view);
    } catch (error) {
      _fail(error, retry: _claimView);
    }
  }

  /// Ad with questions: records the view, which unlocks the answers.
  Future<void> _recordView() async {
    _enter(_Phase.recording);
    try {
      final view = await _postView();
      if (!mounted) return;
      if (view.status == AdViewStatus.failed) {
        // The server did not accept the watch; answering cannot help.
        _finish(view: view);
        return;
      }
      setState(() {
        _questionsOpen = true;
        _phase = _Phase.question;
      });
    } catch (error) {
      _fail(error, retry: _recordView);
    }
  }

  Future<void> _submitAnswers() async {
    final ad = _ad!;
    _enter(_Phase.verifying);
    try {
      final assessment = await ref
          .read(earnRepositoryProvider)
          .submitAdAnswers(
            ad: ad,
            answers: [
              for (final question in ad.questions)
                if (_answers[question.id]?.hasValue ?? false)
                  _answers[question.id]!,
            ],
            idempotencyKey: _answersKey ??= Ids.newId(),
          );
      if (!mounted) return;
      _attempts++;
      _finish(assessment: assessment);
    } catch (error) {
      _fail(error, retry: _submitAnswers);
    }
  }

  /// Starts the answers over after a failed grade, as a new attempt.
  void _answerAgain() => setState(() {
    _answers.clear();
    _index = 0;
    _answersKey = null;
    _assessment = null;
    _phase = _Phase.question;
  });

  void _enter(_Phase phase) => setState(() {
    _phase = phase;
    _failure = null;
    _retry = null;
    _popupHidden = false;
  });

  void _finish({AdView? view, AdAssessment? assessment}) {
    setState(() {
      _result = view;
      _assessment = assessment;
      _phase = _Phase.result;
      _popupHidden = false;
    });
    // The ad (or this attempt at it) is spent — refresh the feeds behind.
    invalidateEarnFeeds(ref);
  }

  void _fail(Object error, {required VoidCallback retry}) {
    if (!mounted) return;
    setState(() {
      _failure = Failure.from(error);
      _retry = retry;
      _phase = _Phase.result;
      _popupHidden = false;
    });
  }

  bool get _attemptsLeft => _attempts < (_ad?.maxAttempts ?? 1);

  /// Quiz questions must all be answered — a blank is a wrong answer anyway.
  /// Survey questions follow their own `isRequired`.
  bool _mustAnswer(SurveyQuestion question) =>
      !_ad!.isSurvey || question.isRequired;

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    } else {
      context.pop();
    }
  }

  void _next() {
    if (_index < _ad!.questions.length - 1) {
      setState(() => _index++);
    } else {
      unawaited(_submitAnswers());
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
              title: 'Loading Advertisement',
              subtitle: 'Please wait a moment',
            )
          : ListStateMessage(message: loadError, onRetry: _reload);
    } else if (_phase == _Phase.recording) {
      body = const PreparingView(
        title: 'Loading Question',
        subtitle: 'Please wait a moment',
        illustration: AppAssets.illustrationLoadingQuiz,
      );
    } else if (_questionsOpen) {
      // Stays behind the Verifying/result popups once submitted.
      final question = ad.questions[_index];
      body = _AdQuestionBody(
        // A new attempt starts every input over, text boxes included.
        key: ValueKey('${question.id}#$_attempts'),
        question: question,
        index: _index,
        total: ad.questions.length,
        answer: _answers[question.id],
        enabled: _phase == _Phase.question,
        canContinue:
            !_mustAnswer(question) ||
            (_answers[question.id]?.hasValue ?? false),
        onChanged: (answer) => setState(() => _answers[question.id] = answer),
        onBack: _back,
        onNext: _next,
      );
    } else {
      body = _WatchBody(playback: _playback!, ad: ad);
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: (preparing && loadError == null) || _phase == _Phase.recording
          ? null
          : _appBar(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (_phase == _Phase.verifying && !_popupHidden)
            EarnPopup(
              illustration: AppAssets.illustrationVerifying,
              title: 'Verifying',
              message: switch (ad.questions.length) {
                0 => 'Please wait while we verify your view',
                1 => 'Please wait while we verify your answer',
                _ => 'Please wait while we verify your answers',
              },
              onClose: () => setState(() => _popupHidden = true),
            ),
          if (_phase == _Phase.result && !_popupHidden)
            _resultPopup(context, ad),
        ],
      ),
    );
  }

  /// Loads the ad; shown until [_adopt] has run.
  ///
  /// `GET /ads/{id}` carries the questions. If it fails — it sits under
  /// "Ad Management" and may be closed to earners — the feed card still
  /// plays the ad, just without questions, as before the endpoint existed.
  Widget _buildGate(BuildContext context) {
    final details = ref.watch(adDetailsProvider(widget.adId));
    final feed = ref.watch(adsFeedProvider);
    final card = feed.value
        ?.where((candidate) => candidate.adId == widget.adId)
        .firstOrNull;

    final VideoAd? found = details.hasValue
        ? details.requireValue.withFallback(card)
        : details.hasError
        ? card
        : null;
    final available = found != null && found.isActive;
    if (available && !_adopting) {
      _adopting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _adopt(found);
      });
    }

    const loading = PreparingView(
      title: 'Loading Advertisement',
      subtitle: 'Please wait a moment',
    );
    final Widget body;
    var showAppBar = true;
    if (available || !details.hasValue && !details.hasError) {
      body = loading;
      showAppBar = false;
    } else if (found != null || details.hasValue || feed.hasValue) {
      // Off sale, or neither source knows it any more.
      body = const ListStateMessage(message: 'This ad is no longer available.');
    } else if (feed.hasError) {
      final error = feed.error;
      body = ListStateMessage(
        message: error is Failure ? error.message : 'Could not load this ad.',
        onRetry: () {
          ref.invalidate(adDetailsProvider(widget.adId));
          ref.invalidate(adsFeedProvider);
        },
      );
    } else {
      body = loading;
      showAppBar = false;
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: showAppBar ? _appBar(context) : null,
      body: body,
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

  Widget _resultPopup(BuildContext context, VideoAd ad) {
    final failure = _failure;
    if (failure != null) {
      // Transport problems are worth another go: the request keeps its
      // idempotency key, so the retry is safe. A domain refusal is final.
      final retryable = failure is NetworkFailure || failure is ServerFailure;
      return EarnPopup(
        illustration: AppAssets.illustrationNotRewarded,
        title: 'Could not verify',
        message: failure.message,
        actionLabel: retryable ? 'Try again' : 'Continue',
        onAction: retryable ? _retry : () => context.pop(),
        onClose: () => context.pop(),
      );
    }

    final assessment = _assessment;
    if (assessment != null) return _assessmentPopup(context, ad, assessment);

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

  Widget _assessmentPopup(
    BuildContext context,
    VideoAd ad,
    AdAssessment assessment,
  ) {
    final yourAnswer = ad.questions.length == 1
        ? 'Your answer is'
        : 'Your answers are';

    if (assessment.passed) {
      return EarnPopup(
        illustration: AppAssets.illustrationCongratulations,
        title: 'Congratulation!',
        message: ad.isSurvey
            ? 'Thanks for your feedback. Your reward will be added to your '
                  'wallet'
            : '$yourAnswer correct. Your reward will be added to your wallet',
        actionLabel: 'Continue',
        onAction: () => context.pop(),
        onClose: () => context.pop(),
      );
    }

    if (ad.isSurvey) {
      return EarnPopup(
        illustration: AppAssets.illustrationNotRewarded,
        title: 'Not rewarded',
        message:
            "Thanks for your feedback. It didn't qualify for a reward "
            'this time.',
        actionLabel: 'Continue',
        onAction: () => context.pop(),
        onClose: () => context.pop(),
      );
    }

    final again = _attemptsLeft;
    return EarnPopup(
      illustration: AppAssets.illustrationNotRewarded,
      title: 'Wrong Answer!',
      message: again
          ? '$yourAnswer not correct. Watch closely and try again.'
          : '$yourAnswer not correct. You didn’t earn the reward this time.',
      actionLabel: again ? 'Try again' : 'Continue',
      onAction: again ? _answerAgain : () => context.pop(),
      secondaryLabel: again ? 'Exit' : null,
      onSecondary: again ? () => context.pop() : null,
      onClose: () => context.pop(),
    );
  }
}

class _WatchBody extends StatelessWidget {
  const _WatchBody({required this.playback, required this.ad});

  final VideoPlayback playback;
  final VideoAd ad;

  String get _hint {
    if (!ad.hasQuestions) {
      return 'Watch the full video without skipping. Your reward is '
          'verified as soon as it ends.';
    }
    if (ad.isSurvey) {
      return 'After the video, a few questions will appear. Answer them to '
          'earn the reward.';
    }
    return ad.questions.length == 1
        ? 'After the video, a question will appear. To earn the reward you '
              'need to answer the question correctly.'
        : 'After the video, ${ad.questions.length} questions will appear. To '
              'earn the reward you need to answer them correctly.';
  }

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
            _hint,
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

/// One post-video question (Figma V3 "Watch Ad" question step): the
/// question, a divider, the answers, then Back and Next/Submit.
///
/// Back steps to the previous question, or leaves the ad from the first —
/// without claiming the reward.
class _AdQuestionBody extends StatelessWidget {
  const _AdQuestionBody({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.answer,
    required this.enabled,
    required this.canContinue,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final SurveyQuestion question;
  final int index;
  final int total;
  final SurveyAnswer? answer;
  final bool enabled;
  final bool canContinue;
  final ValueChanged<SurveyAnswer> onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The single-question design has no counter; add one only
                // when there is more than one step.
                if (total > 1) ...[
                  Text(
                    'Question ${index + 1} of $total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
                IgnorePointer(
                  ignoring: !enabled,
                  child: AnswerInput(
                    question: question,
                    answer: answer,
                    onChanged: onChanged,
                  ),
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
                    label: isLast ? 'Submit' : 'Next',
                    onPressed: enabled && canContinue ? onNext : null,
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

/// An image or GIF creative. A broken link falls back to the no-media
/// frame rather than an error: the timer still counts the watch.
class _ImageSurface extends StatelessWidget {
  const _ImageSurface({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _NoVideoSurface(title: title),
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
