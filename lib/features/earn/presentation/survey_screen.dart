import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/error/failure.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/question_scaffold.dart';

/// Survey runner (Figma: "Uparjon - Survey 1..5").
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

  bool _isAnswered(SurveyQuestion question) {
    final answer = _answers[question.id];
    if (answer == null) return false;
    return answer.optionId != null ||
        (answer.optionIds?.isNotEmpty ?? false) ||
        (answer.textAnswer?.trim().isNotEmpty ?? false);
  }

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
      SnackbarService.showFailure(Failure.from(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surveyDetailsProvider(widget.surveyId));

    return PopScope(
      // Intercept the system back button so the slot is released first.
      canPop: _submitted || _slotReleased,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Survey',
            style: TextStyle(fontSize: 18, color: AppColors.ink),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.ink,
            onPressed: _leave,
          ),
        ),
        body: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
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
            if (_submitted) return _SubmittedView(onDone: () => context.pop());
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
              canGoBack: _index > 0,
              // Optional questions can be skipped; required ones cannot.
              canGoNext: answered || !question.isRequired,
              isLast: isLast,
              busy: _submitting,
              onBack: () => setState(() => _index--),
              onNext: () => isLast ? _submit(survey) : setState(() => _index++),
              child: _AnswerInput(
                question: question,
                answer: _answers[question.id],
                onChanged: (answer) =>
                    setState(() => _answers[question.id] = answer),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders the right control for each of the API's question types.
class _AnswerInput extends StatelessWidget {
  const _AnswerInput({
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  final SurveyQuestion question;
  final SurveyAnswer? answer;
  final ValueChanged<SurveyAnswer> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case SurveyQuestionType.multipleChoice:
        final selected = answer?.optionIds ?? const <String>[];
        return Column(
          children: [
            for (final option in question.options)
              ChoiceTile(
                label: option.text,
                multi: true,
                selected: selected.contains(option.id),
                onTap: () {
                  final next = [...selected];
                  next.contains(option.id)
                      ? next.remove(option.id)
                      : next.add(option.id);
                  onChanged(
                    SurveyAnswer(questionId: question.id, optionIds: next),
                  );
                },
              ),
          ],
        );

      case SurveyQuestionType.boolean:
        final selected = answer?.textAnswer;
        return Column(
          children: [
            for (final value in ['Yes', 'No'])
              ChoiceTile(
                label: value,
                selected: selected == value,
                onTap: () => onChanged(
                  SurveyAnswer(questionId: question.id, textAnswer: value),
                ),
              ),
          ],
        );

      case SurveyQuestionType.rating:
        final min = question.minVal ?? 1;
        final max = question.maxVal ?? 5;
        final current = int.tryParse(answer?.textAnswer ?? '');
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var value = min; value <= max; value++)
              _RatingChip(
                value: value,
                selected: current == value,
                onTap: () => onChanged(
                  SurveyAnswer(questionId: question.id, textAnswer: '$value'),
                ),
              ),
          ],
        );

      case SurveyQuestionType.text:
        return TextFormField(
          initialValue: answer?.textAnswer,
          maxLines: 5,
          minLines: 3,
          style: const TextStyle(fontSize: 15, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Type your answer',
            hintStyle: const TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
            ),
          ),
          onChanged: (value) => onChanged(
            SurveyAnswer(questionId: question.id, textAnswer: value),
          ),
        );

      case SurveyQuestionType.singleChoice:
      case SurveyQuestionType.unknown:
        return Column(
          children: [
            for (final option in question.options)
              ChoiceTile(
                label: option.text,
                selected: answer?.optionId == option.id,
                onTap: () => onChanged(
                  SurveyAnswer(questionId: question.id, optionId: option.id),
                ),
              ),
          ],
        );
    }
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.amber : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.amber : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          const Text(
            'Survey submitted',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your reward is queued and will land in your wallet '
            'once it passes review.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.slate),
          ),
          const SizedBox(height: 32),
          AppButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
