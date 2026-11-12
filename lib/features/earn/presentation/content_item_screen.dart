import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_env.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/app_exception.dart';
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

/// Runs one campaign item — ad, quiz or survey — from the Ads/Quiz/Survey
/// lists or the campaign screen (Figma V3 "Watch Ad": media → question →
/// "Verifying" → "Congratulation!" / "Wrong Answer!"), per the ad-view flow
/// of `docs/API Docs V3/document.pdf` (Mobile API changes 2026-11-11 §1).
///
/// The item comes from `GET /mobile/content/{id}`. Its media cannot be
/// skipped — the only controls are play/pause and mute — and it is earned
/// through `/ad-views/*`:
///
/// 1. `start` when the user first presses play. It pays nothing and hands
///    back the `adViewId` the later steps take. Playback waits for it, so
///    the server's clock runs for at least as long as the media plays;
/// 2. `complete` when the media ends. A plain ad is paid here. An item with
///    questions comes back `awaitingAnswers`;
/// 3. `answers`: the questions, walked one at a time and submitted once,
///    which is what pays.
///
/// An item already watched (`ANSWERS_PENDING`) opens straight on its
/// questions when this device kept its `adViewId`; otherwise the media plays
/// again. Standalone quizzes and surveys never come here — they have no
/// media and their own screens.
class ContentItemScreen extends ConsumerStatefulWidget {
  const ContentItemScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ContentItemScreen> createState() => _ContentItemScreenState();
}

enum _Phase { preparing, watching, recording, question, verifying, result }

class _ContentItemScreenState extends ConsumerState<ContentItemScreen>
    with WidgetsBindingObserver {
  ContentDetail? _detail;
  VideoPlayback? _playback;
  _Phase _phase = _Phase.preparing;
  String? _loadError;
  VideoPlaybackState? _finalState;

  /// `start` is in flight.
  bool _starting = false;

  /// The view the server opened for this watch — playback may run once it
  /// is set.
  String? _adViewId;

  /// Outcome of the view alone — set for items without questions, or when
  /// the server refused the view outright.
  AdView? _result;

  /// Outcome of the answers.
  AdAssessment? _assessment;
  Failure? _failure;

  /// Repeats whichever request produced [_failure].
  VoidCallback? _retry;

  /// One key per request the user may retry, so a retry after a dropped
  /// connection is the same request to the server and cannot pay twice.
  String? _startKey;
  String? _completeKey;
  String? _answersKey;

  /// The view has counted, so the questions may be answered.
  bool _questionsOpen = false;
  int _index = 0;
  final Map<String, SurveyAnswer> _answers = {};
  bool _popupHidden = false;
  bool _adopting = false;

  ContentItem get _item => _detail!.item;
  List<SurveyQuestion> get _questions => _detail!.questions;
  bool get _hasQuestions => _questions.isNotEmpty;

  EarnRepository get _repo => ref.read(earnRepositoryProvider);

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

  /// Takes the item once and keeps it: the lists are invalidated after the
  /// view is recorded, and this screen must not blank out then.
  void _adopt(ContentDetail detail) {
    if (_detail != null) return;
    setState(() => _detail = detail);
    final pending = detail.item.progress == ContentProgress.answersPending
        ? _repo.pendingAdView(detail.item.id)
        : null;
    if (pending != null && detail.questions.isNotEmpty) {
      // Watched already; the answers go to that same view.
      setState(() {
        _adViewId = pending;
        _questionsOpen = true;
        _phase = _Phase.question;
      });
      return;
    }
    unawaited(_prepare(detail.item));
  }

  Future<void> _prepare(ContentItem item) async {
    final url = Uri.tryParse(AppEnv.resolveMediaUrl(item.mediaUrl) ?? '');
    final length = Duration(seconds: item.durationSeconds ?? 0);
    // Stills and GIFs have no clock of their own, so a timer stands in for
    // the video's — the watch rule is the same.
    final playback = url == null || !url.hasScheme
        ? TimedPlayback(length, surface: _NoVideoSurface(title: item.title))
        : item.isImage
        ? TimedPlayback(
            length,
            surface: _ImageSurface(url: url.toString(), title: item.title),
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
    if (_detail == null) return;
    setState(() {
      _loadError = null;
      _phase = _Phase.preparing;
    });
    unawaited(_prepare(_item));
  }

  void _onPlayback() {
    if (!mounted) return;
    final state = _playback!.state.value;
    if (state.completed && _phase == _Phase.watching) {
      _finalState = state;
      unawaited(_completeView());
      return;
    }
    setState(() {});
  }

  /// The play button. The first press opens the view on the server before
  /// any media plays.
  void _play() {
    if (_adViewId != null) {
      unawaited(_playback!.play());
    } else {
      unawaited(_startView());
    }
  }

  Future<void> _startView() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final session = await _repo.startAdView(
        itemId: _item.id,
        idempotencyKey: _startKey ??= Ids.newId(),
      );
      if (!mounted) return;
      setState(() {
        _starting = false;
        _adViewId = session.adViewId;
      });
      unawaited(_playback!.play());
    } catch (error) {
      if (mounted) setState(() => _starting = false);
      _fail(error, retry: _retryStart);
    }
  }

  void _retryStart() {
    _enter(_Phase.watching);
    unawaited(_startView());
  }

  int get _watchedSeconds {
    final state = _finalState!;
    return math.max(state.position.inSeconds, state.duration.inSeconds);
  }

  /// The media ended: completes the view, which pays a plain ad and unlocks
  /// the questions of any other item.
  Future<void> _completeView() async {
    _enter(_hasQuestions ? _Phase.recording : _Phase.verifying);
    try {
      final view = await _repo.completeAdView(
        itemId: _item.id,
        adViewId: _adViewId!,
        watchedSeconds: _watchedSeconds,
        idempotencyKey: _completeKey ??= Ids.newId(),
      );
      if (!mounted) return;
      _onViewCounted(view);
    } catch (error) {
      _fail(error, retry: _completeView);
    }
  }

  void _onViewCounted(AdView view) {
    final counted =
        view.awaitingAnswers || view.status == AdViewStatus.completed;
    if (_hasQuestions && counted) {
      setState(() {
        _questionsOpen = true;
        _phase = _Phase.question;
      });
    } else {
      _finish(view: view);
    }
  }

  Future<void> _submitAnswers() async {
    _enter(_Phase.verifying);
    try {
      final assessment = await _repo.submitAnswers(
        item: _item,
        adViewId: _adViewId!,
        // The server wants exactly one answer per question; Next stays
        // disabled until each has one.
        answers: [for (final question in _questions) _answers[question.id]!],
        idempotencyKey: _answersKey ??= Ids.newId(),
      );
      if (!mounted) return;
      _finish(assessment: assessment);
    } catch (error) {
      // Refused for good (done already, the view is not usable): there is
      // nothing left to send the answers to later.
      if (Failure.from(error) is BusinessFailure) {
        unawaited(_repo.forgetPendingAdView(_item.id));
      }
      _fail(error, retry: _submitAnswers);
    }
  }

  /// Back to the questions after the server refused an answer, with the
  /// answers kept so only the wrong one needs changing.
  void _reviewAnswers() => setState(() {
    _index = 0;
    _answersKey = null;
    _failure = null;
    _retry = null;
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
    // The item is spent — refresh the lists behind.
    invalidateEarnFeeds(ref);
  }

  void _fail(Object error, {required VoidCallback retry}) {
    if (!mounted) return;
    final failure = Failure.from(error);
    if (failure is BusinessFailure && failure.retryable) {
      // The server rolled the refused request back; replaying its key would
      // only replay the refusal.
      _completeKey = null;
    }
    setState(() {
      _failure = failure;
      _retry = retry;
      _phase = _Phase.result;
      _popupHidden = false;
    });
    // Done already, the campaign closed, the user fell out of its audience:
    // the lists behind are out of date.
    if (failure is BusinessFailure) invalidateEarnFeeds(ref);
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
    } else {
      context.pop();
    }
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
    } else {
      unawaited(_submitAnswers());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_detail == null) return _buildGate(context);
    final item = _item;

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
      final question = _questions[_index];
      body = _AdQuestionBody(
        key: ValueKey(question.id),
        question: question,
        index: _index,
        total: _questions.length,
        answer: _answers[question.id],
        enabled: _phase == _Phase.question,
        canContinue: _answers[question.id]?.hasValue ?? false,
        onChanged: (answer) => setState(() => _answers[question.id] = answer),
        onBack: _back,
        onNext: _next,
      );
    } else {
      body = _WatchBody(
        playback: _playback!,
        item: item,
        questionCount: _questions.length,
        starting: _starting,
        onPlay: _play,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: (preparing && loadError == null) || _phase == _Phase.recording
          ? null
          : _appBar(context, item.kind),
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (_phase == _Phase.verifying && !_popupHidden)
            EarnPopup(
              illustration: AppAssets.illustrationVerifying,
              title: 'Verifying',
              message: switch (_questions.length) {
                0 => 'Please wait while we verify your view',
                1 => 'Please wait while we verify your answer',
                _ => 'Please wait while we verify your answers',
              },
              onClose: () => setState(() => _popupHidden = true),
            ),
          if (_phase == _Phase.result && !_popupHidden)
            _resultPopup(context, item),
        ],
      ),
    );
  }

  /// Loads the item; shown until [_adopt] has run.
  Widget _buildGate(BuildContext context) {
    final async = ref.watch(contentDetailProvider(widget.itemId));
    final detail = async.value;
    final item = detail?.item;

    final Widget? body;
    if (item != null && item.canStart) {
      if (!_adopting) {
        _adopting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _adopt(detail!);
        });
      }
      body = null;
    } else if (item != null) {
      body = ListStateMessage(
        message: item.isCompleted
            ? 'You have already completed this one.'
            : item.unavailableMessage ?? 'This is not available right now.',
      );
    } else if (async.hasError) {
      final failure = Failure.from(async.error!);
      final gone = failure.code == ApiErrorCodes.notFound;
      body = ListStateMessage(
        message: gone ? 'This is no longer available.' : failure.message,
        onRetry: gone
            ? null
            : () => ref.invalidate(contentDetailProvider(widget.itemId)),
      );
    } else {
      body = null;
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: body == null ? null : _appBar(context, item?.kind),
      body:
          body ??
          const PreparingView(
            title: 'Loading Advertisement',
            subtitle: 'Please wait a moment',
          ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, ContentKind? kind) =>
      AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(switch (kind) {
          ContentKind.quiz => 'Quiz',
          ContentKind.survey => 'Survey',
          _ => 'Watch Ad',
        }, style: const TextStyle(fontSize: 18, color: AppColors.ink)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
      );

  Widget _resultPopup(BuildContext context, ContentItem item) {
    final failure = _failure;
    if (failure != null) return _failurePopup(context, failure);

    final assessment = _assessment;
    if (assessment != null) return _assessmentPopup(context, item, assessment);

    final view = _result;
    final rewarded = view?.isRewarded ?? false;
    final paid = view?.rewardEarned;
    return EarnPopup(
      illustration: rewarded
          ? AppAssets.illustrationCongratulations
          : AppAssets.illustrationNotRewarded,
      title: rewarded ? 'Congratulation!' : 'Not rewarded',
      message: rewarded
          ? 'You watched the full ad. ${_earnedLine(paid)}'
          : "This view didn't qualify for a reward this time.",
      actionLabel: 'Continue',
      onAction: () => context.pop(),
      onClose: () => context.pop(),
    );
  }

  Widget _failurePopup(BuildContext context, Failure failure) {
    if (failure.code == ApiErrorCodes.invalidAnswer) {
      return EarnPopup(
        illustration: AppAssets.illustrationAlert,
        title: 'Check your answers',
        message: failure.message,
        actionLabel: 'Review answers',
        onAction: _reviewAnswers,
        onClose: _reviewAnswers,
      );
    }

    // Transport problems are worth another go: the request keeps its
    // idempotency key, so the retry is safe. So is a view completed a little
    // too soon. Any other domain refusal is final.
    final retryable =
        failure is NetworkFailure ||
        failure is ServerFailure ||
        (failure is BusinessFailure && failure.retryable);
    return EarnPopup(
      illustration: AppAssets.illustrationNotRewarded,
      title: 'Could not verify',
      message: failure.message,
      actionLabel: retryable ? 'Try again' : 'Continue',
      onAction: retryable ? _retry : () => context.pop(),
      onClose: () => context.pop(),
    );
  }

  Widget _assessmentPopup(
    BuildContext context,
    ContentItem item,
    AdAssessment assessment,
  ) {
    final yourAnswer = _questions.length == 1
        ? 'Your answer is'
        : 'Your answers are';
    final cashback = _cashbackLine(assessment);
    final paid = assessment.rewardEarned;

    // Only cashback came of it: nothing is in the wallet yet, so it must not
    // read as earned.
    if (!assessment.earned && cashback != null) {
      return EarnPopup(
        illustration: AppAssets.illustrationSuccess,
        title: 'Cashback reserved',
        message: cashback,
        actionLabel: 'Continue',
        onAction: () => context.pop(),
        onClose: () => context.pop(),
      );
    }

    // A server that leaves out `rewardEarned` has still paid a pass.
    if (assessment.earned || (assessment.passed && paid == null)) {
      final lead = item.isSurvey
          ? 'Thanks for your feedback.'
          : assessment.passed
          ? '$yourAnswer correct.'
          : null;
      return EarnPopup(
        illustration: AppAssets.illustrationCongratulations,
        title: 'Congratulation!',
        message: [?lead, _earnedLine(paid), ?cashback].join(' '),
        actionLabel: 'Continue',
        onAction: () => context.pop(),
        onClose: () => context.pop(),
      );
    }

    if (item.isSurvey) {
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

    // One submission per item: a failed quiz is done for good.
    return EarnPopup(
      illustration: AppAssets.illustrationNotRewarded,
      title: 'Wrong Answer!',
      message: '$yourAnswer not correct. You didn’t earn the reward this time.',
      actionLabel: 'Continue',
      onAction: () => context.pop(),
      onClose: () => context.pop(),
    );
  }

  /// A reward may be held for review instead of paid at once, and the reply
  /// looks the same either way (Mobile API changes 2026-11-11 §5) — so never
  /// promise it is already spendable.
  static String _earnedLine(num? paid) {
    final lead = paid != null && paid > 0
        ? 'You earned ${Formatters.taka(paid)}.'
        : 'Your reward is on its way.';
    return '$lead Some rewards are reviewed first and show as pending in '
        'your wallet.';
  }

  /// "Buy the product by … to get ৳X cashback." — promised, paid only after
  /// the purchase is delivered and its return window has passed.
  static String? _cashbackLine(AdAssessment assessment) {
    if (!assessment.hasCashback) return null;
    final amount = Formatters.taka(assessment.cashbackPromised!);
    final deadlines = [
      for (final promise in assessment.cashback) ?promise.purchaseDeadline,
    ]..sort();
    final by = deadlines.isEmpty
        ? 'in time'
        : 'by ${Formatters.activityTime(deadlines.first)}';
    return 'Buy the product from the store $by to get $amount cashback.';
  }
}

class _WatchBody extends StatelessWidget {
  const _WatchBody({
    required this.playback,
    required this.item,
    required this.questionCount,
    required this.starting,
    required this.onPlay,
  });

  final VideoPlayback playback;
  final ContentItem item;
  final int questionCount;
  final bool starting;
  final VoidCallback onPlay;

  String get _media => item.isImage ? 'image' : 'video';

  String get _hint {
    if (questionCount == 0) {
      return 'Watch the full $_media without skipping. Your reward is '
          'verified as soon as it ends.';
    }
    if (item.isSurvey) {
      return 'After the $_media, a few questions will appear. Answer them to '
          'earn the reward.';
    }
    return questionCount == 1
        ? 'After the $_media, a question will appear. To earn the reward you '
              'need to answer the question correctly.'
        : 'After the $_media, $questionCount questions will appear. To '
              'earn the reward you need to answer them correctly.';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        children: [
          _Player(playback: playback, starting: starting, onPlay: onPlay),
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

/// One post-media question (Figma V3 "Watch Ad" question step): the
/// question, a divider, the answers, then Back and Next/Submit. Every
/// question must be answered, so Next waits for an answer.
///
/// Back steps to the previous question, or leaves the item from the first —
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
    final image = question.hasImage
        ? AppEnv.resolveMediaUrl(question.mediaUrl)
        : null;
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
                if (image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                if (question.isCashback) ...[
                  const SizedBox(height: 12),
                  _CashbackNote(question: question),
                ],
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

/// A purchase-cashback question: answering reserves cashback that is paid
/// only once the user buys the product from the platform store.
class _CashbackNote extends StatelessWidget {
  const _CashbackNote({required this.question});

  final SurveyQuestion question;

  @override
  Widget build(BuildContext context) {
    final amount = question.rewardAmount;
    final days = question.purchaseWindowDays;
    final within = days == null
        ? ''
        : ' within $days ${days == 1 ? 'day' : 'days'}';
    final reward = amount == null
        ? 'cashback'
        : '${Formatters.taka(amount)} cashback';
    final link = question.productUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buy this product from the store$within to get $reward.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppColors.greenDeep,
            ),
          ),
          if (link != null && link.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              link,
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ],
        ],
      ),
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
///
/// Play goes through [onPlay], which opens the view on the server first; a
/// spinner stands in for the button while [starting].
class _Player extends StatelessWidget {
  const _Player({
    required this.playback,
    required this.starting,
    required this.onPlay,
  });

  final VideoPlayback playback;
  final bool starting;
  final VoidCallback onPlay;

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
                    } else if (!starting) {
                      onPlay();
                    }
                  },
                  child: Center(
                    child: state.playing
                        ? const SizedBox.shrink()
                        : starting
                        ? const CircularProgressIndicator(color: Colors.white)
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

/// Stand-in frames for an item that arrived without media.
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
