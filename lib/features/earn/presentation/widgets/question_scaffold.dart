import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/ui/app_button.dart';

/// Shared chrome for the one-question-per-step runners
/// (Figma: "Uparjon - Survey 1..5").
///
/// Title, a segmented progress bar, the numbered question, the answer widget,
/// and the Back/Next pair.
class QuestionScaffold extends StatelessWidget {
  const QuestionScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.total,
    required this.questionNumber,
    required this.questionText,
    required this.child,
    required this.canGoBack,
    required this.canGoNext,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    this.busy = false,
  });

  final String title;
  final int step;
  final int total;
  final int questionNumber;
  final String questionText;
  final Widget child;
  final bool canGoBack;
  final bool canGoNext;
  final bool isLast;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                _SegmentedProgress(step: step, total: total),
                const SizedBox(height: 6),
                Text(
                  '$step/$total',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$questionNumber. ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        questionText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.soft,
                    onPressed: canGoBack && !busy ? onBack : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    label: isLast ? 'Submit' : 'Next',
                    loading: busy,
                    onPressed: canGoNext ? onNext : null,
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

/// The design's progress bar: one segment per question, filled up to [step].
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 5,
              decoration: BoxDecoration(
                color: i < step ? AppColors.amber : AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A selectable answer row (radio for single choice, check for multi).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.multi = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? const Color(0xFFFEF6E7) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.amber : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  multi
                      ? (selected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                      : (selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                  size: 22,
                  color: selected ? AppColors.amber : AppColors.divider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 15, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
