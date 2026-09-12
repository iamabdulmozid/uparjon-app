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
import 'widgets/question_scaffold.dart';

/// Quiz runner — one question per step, then a score screen.
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quizDetailsProvider(widget.quizId));

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Quiz',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
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
              error is Failure ? error.message : 'Could not load this quiz.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate),
            ),
          ),
        ),
        data: (quiz) {
          if (_result != null) {
            return _QuizResultView(
              result: _result!,
              onDone: () => context.pop(),
            );
          }
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
            onNext: () => isLast ? _submit(quiz) : setState(() => _index++),
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
    );
  }
}

class _QuizResultView extends StatelessWidget {
  const _QuizResultView({required this.result, required this.onDone});

  final QuizResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            result.passed ? Icons.emoji_events : Icons.replay_circle_filled,
            size: 64,
            color: result.passed ? AppColors.amber : AppColors.slate,
          ),
          const SizedBox(height: 16),
          Text(
            '${result.score} / ${result.totalQuestions}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.passed ? 'Well done!' : 'Not quite this time.',
            style: const TextStyle(fontSize: 16, color: AppColors.slate),
          ),
          if (result.reward != null) ...[
            const SizedBox(height: 12),
            Text(
              'Earned ${Formatters.taka(result.reward!)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF005B3D),
              ),
            ),
          ],
          const SizedBox(height: 32),
          AppButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
