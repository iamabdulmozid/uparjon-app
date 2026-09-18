import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/failure.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/earn_popup.dart';
import 'widgets/preparing_view.dart';
import 'widgets/question_scaffold.dart';

/// Quiz runner (Figma V2: "Uparjon - Loading Quiz" → "Uparjon - Quiz", with
/// the "Alert" and "Success" popups).
///
/// The design also shows free-text and multi-select questions, but the quiz
/// API only takes one option id per question, so every question renders as
/// single choice.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final Map<String, String> _answers = {};
  int _index = 0;
  bool _submitting = false;
  bool _confirmingExit = false;
  QuizResult? _result;

  Future<void> _submit(QuizDetails quiz) async {
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(earnRepositoryProvider)
          .submitQuiz(quizId: quiz.id, answers: _answers);
      if (!mounted) return;
      setState(() => _result = result);
      invalidateEarnFeeds(ref);
    } catch (error) {
      if (!mounted) return;
      SnackbarService.showFailure(Failure.from(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _confirmExit() {
    if (_submitting) return;
    // Nothing to lose before the quiz has loaded or once it is submitted.
    final loaded = ref.read(quizDetailsProvider(widget.quizId)).hasValue;
    if (!loaded || _result != null) {
      context.pop();
      return;
    }
    setState(() => _confirmingExit = true);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quizDetailsProvider(widget.quizId));
    final loading = async.isLoading && !async.hasValue;
    final result = _result;

    return PopScope(
      canPop: result != null || !async.hasValue,
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
                  'Quiz',
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
                title: 'Loading Quiz',
                subtitle: 'Please wait a moment',
                illustration: AppAssets.illustrationLoadingQuiz,
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error is Failure
                        ? error.message
                        : 'Could not load this quiz.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate),
                  ),
                ),
              ),
              data: (quiz) {
                if (quiz.questions.isEmpty) {
                  return const Center(
                    child: Text(
                      'This quiz has no questions yet.',
                      style: TextStyle(color: AppColors.slate),
                    ),
                  );
                }

                final question = quiz.questions[_index];
                final selected = _answers[question.id];
                final isLast = _index == quiz.questions.length - 1;

                return QuestionScaffold(
                  title: quiz.title,
                  step: _index + 1,
                  total: quiz.questions.length,
                  questionNumber: _index + 1,
                  questionText: question.text,
                  canGoBack: _index > 0,
                  canGoNext: selected != null,
                  isLast: isLast,
                  busy: _submitting,
                  onBack: () => setState(() => _index--),
                  onNext: () =>
                      isLast ? _submit(quiz) : setState(() => _index++),
                  onFinishNow: _confirmExit,
                  child: Column(
                    children: [
                      for (final option in question.options)
                        ChoiceTile(
                          label: option.text,
                          selected: selected == option.id,
                          onTap: () =>
                              setState(() => _answers[question.id] = option.id),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (result != null)
              _ResultPopup(result: result, onDone: () => context.pop())
            else if (_confirmingExit)
              EarnPopup(
                illustration: AppAssets.illustrationAlert,
                title: 'Alert',
                message:
                    'Do you really want to finish the quiz now? If you do so '
                    'you won’t get any reward.',
                secondaryLabel: 'Back',
                onSecondary: () => setState(() => _confirmingExit = false),
                actionLabel: 'Finish Quiz',
                actionVariant: AppButtonVariant.danger,
                onAction: () => context.pop(),
                onClose: () => setState(() => _confirmingExit = false),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Success" when the quiz paid out, otherwise the not-rewarded variant with
/// the score.
class _ResultPopup extends StatelessWidget {
  const _ResultPopup({required this.result, required this.onDone});

  final QuizResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final score = '${result.score}/${result.totalQuestions}';
    return EarnPopup(
      illustration: result.passed
          ? AppAssets.illustrationSuccess
          : AppAssets.illustrationNotRewarded,
      title: result.passed ? 'Success' : 'Not rewarded',
      message: result.passed
          ? 'You have successfully completed the quiz. Your reward will be '
                'added to your wallet'
          : "You scored $score. You didn't earn the reward this time.",
      actionLabel: 'Continue',
      onAction: onDone,
      onClose: onDone,
    );
  }
}
