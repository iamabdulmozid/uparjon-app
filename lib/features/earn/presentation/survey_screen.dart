import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/error/failure.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/app_button.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/earn_popup.dart';
import 'widgets/preparing_view.dart';
import 'widgets/answer_input.dart';
import 'widgets/question_scaffold.dart';

/// Survey runner (Figma V2: "Uparjon - Loading Survey" → "Uparjon - Survey",
/// with the "Alert" and "Success" popups).
///
/// Surveys have a limited number of concurrent slots, so this screen holds one
/// open with a heartbeat while the user answers and releases it on the way out.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key, required this.surveyId});

  final String surveyId;

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  /// Comfortably inside a typical slot expiry.
  static const Duration _heartbeatEvery = Duration(seconds: 30);

  final Map<String, SurveyAnswer> _answers = {};
  Timer? _heartbeat;
  int _index = 0;
  bool _submitting = false;
  bool _submitted = false;
  bool _slotReleased = false;

  /// The "Finish Now" confirmation is on screen.
  bool _confirmingExit = false;

  /// Captured in [initState]: `ref.read` is not allowed once the widget is
  /// being disposed, and that is exactly when the slot must be released.
  late final EarnRepository _repo = ref.read(earnRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _repo;
    _startHeartbeat();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }

  /// Leaves the survey, handing the concurrency slot back first.
  ///
  /// Released here rather than in `dispose` because a request fired while the
  /// widget is being torn down is not guaranteed to leave the device.
  Future<void> _leave() async {
    _heartbeat?.cancel();
    await _releaseSlot();
    if (mounted) context.pop();
  }

  Future<void> _releaseSlot() async {
    if (_submitted || _slotReleased) return;
    _slotReleased = true;
    try {
      await _repo.discardSurvey(widget.surveyId);
    } catch (_) {
      // The server expires the slot on its own if this never lands.
    }
  }

  void _startHeartbeat() {
    unawaited(_beat());
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) => _beat());
  }

  Future<void> _beat() async {
    try {
      await _repo.surveyHeartbeat(widget.surveyId);
    } catch (_) {
      // A missed heartbeat is not worth interrupting the user; the submit
      // call is what actually reports whether the slot was lost.
    }
  }

  bool _isAnswered(SurveyQuestion question) =>
      _answers[question.id]?.hasValue ?? false;

  Future<void> _submit(SurveyDetails survey) async {
    setState(() => _submitting = true);
    try {
      await _repo.submitSurvey(
        surveyId: survey.id,
        answers: _answers.values.toList(),
      );
      if (!mounted) return;
      _heartbeat?.cancel();
      setState(() {
        _submitted = true;
        _submitting = false;
      });
      invalidateEarnFeeds(ref);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final failure = Failure.from(error);
      // A survey the server has already paid out can never succeed on retry,
      // so refresh the feeds — it should drop off the list rather than invite
      // the user to fill it in again.
      if (failure.code == ApiErrorCodes.illegalState) invalidateEarnFeeds(ref);
      SnackbarService.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surveyDetailsProvider(widget.surveyId));
    final loading = async.isLoading && !async.hasValue;

    return PopScope(
      // Intercept the system back button so the user confirms and the slot
      // is released first.
      canPop: _submitted || _slotReleased,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: loading
            ? null
            : AppBar(
                backgroundColor: AppColors.creamLight,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                title: const Text(
                  'Survey',
                  style: TextStyle(fontSize: 18, color: AppColors.ink),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: AppColors.ink,
                  onPressed: _confirmExit,
                ),
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            async.when(
              loading: () => const PreparingView(
                title: 'Loading Survey',
                subtitle: 'Please wait a moment',
                illustration: AppAssets.illustrationLoadingSurvey,
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error is Failure
                        ? error.message
                        : 'Could not load this survey.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate),
                  ),
                ),
              ),
              data: (survey) {
                if (survey.questions.isEmpty) {
                  return const Center(
                    child: Text(
                      'This survey has no questions yet.',
                      style: TextStyle(color: AppColors.slate),
                    ),
                  );
                }

                final question = survey.questions[_index];
                final isLast = _index == survey.questions.length - 1;
                final answered = _isAnswered(question);

                return QuestionScaffold(
                  title: survey.title,
                  step: _index + 1,
                  total: survey.questions.length,
                  questionNumber: _index + 1,
                  questionText: question.text,
                  questionHint:
                      question.type == SurveyQuestionType.multipleChoice
                      ? 'Select all that apply.'
                      : null,
                  canGoBack: _index > 0,
                  // Optional questions can be skipped; required ones cannot.
                  canGoNext: answered || !question.isRequired,
                  isLast: isLast,
                  busy: _submitting,
                  onBack: () => setState(() => _index--),
                  onNext: () =>
                      isLast ? _submit(survey) : setState(() => _index++),
                  onFinishNow: _confirmExit,
                  child: AnswerInput(
                    // Keeps the text box from carrying one question's draft
                    // over to the next.
                    key: ValueKey(question.id),
                    question: question,
                    answer: _answers[question.id],
                    onChanged: (answer) =>
                        setState(() => _answers[question.id] = answer),
                  ),
                );
              },
            ),
            if (_submitted)
              EarnPopup(
                illustration: AppAssets.illustrationSuccess,
                title: 'Success',
                message:
                    'You have successfully completed the survey. Your reward '
                    'will be added to your wallet',
                actionLabel: 'Continue',
                onAction: () => context.pop(),
                onClose: () => context.pop(),
              )
            else if (_confirmingExit)
              EarnPopup(
                illustration: AppAssets.illustrationAlert,
                title: 'Alert',
                message:
                    'Do you really want to finish the survey now? If you do '
                    'so you won’t get any reward.',
                secondaryLabel: 'Back',
                onSecondary: _dismissExit,
                actionLabel: 'Finish Survey',
                actionVariant: AppButtonVariant.danger,
                onAction: _leave,
                onClose: _dismissExit,
              ),
          ],
        ),
      ),
    );
  }

  void _confirmExit() {
    if (_submitting) return;
    // Nothing to lose before the survey has loaded.
    if (!ref.read(surveyDetailsProvider(widget.surveyId)).hasValue) {
      unawaited(_leave());
      return;
    }
    setState(() => _confirmingExit = true);
  }

  void _dismissExit() => setState(() => _confirmingExit = false);
}
