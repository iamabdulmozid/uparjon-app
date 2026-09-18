import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/ui/app_button.dart';

/// Shared chrome for the one-question-per-step runners
/// (Figma V2: "Uparjon - Survey", "Uparjon - Quiz").
///
/// Title, a segmented progress bar with the step counter and "Finish Now",
/// the numbered question, the answer widget, and the Back/Next pair.
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
    this.questionHint,
    this.onFinishNow,
    this.busy = false,
  });

  final String title;
  final int step;
  final int total;
  final int questionNumber;
  final String questionText;

  /// Italic aside after the question, e.g. "Select all that apply."
  final String? questionHint;
  final Widget child;
  final bool canGoBack;
  final bool canGoNext;
  final bool isLast;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// Shows the red "Finish Now" link; the caller confirms before leaving.
  final VoidCallback? onFinishNow;

  static const _questionStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.375,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                _SegmentedProgress(step: step, total: total),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$step/$total',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate,
                      ),
                    ),
                    const Spacer(),
                    if (onFinishNow != null)
                      GestureDetector(
                        onTap: busy ? null : onFinishNow,
                        behavior: HitTestBehavior.opaque,
                        child: const Text(
                          'Finish Now',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.dangerText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$questionNumber. ', style: _questionStyle),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: questionText,
                                  children: [
                                    if (questionHint != null)
                                      TextSpan(
                                        text: ' $questionHint',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.slate,
                                        ),
                                      ),
                                  ],
                                ),
                                style: _questionStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 16),
                      child,
                    ],
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
                  flex: 2,
                  child: AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.soft,
                    onPressed: canGoBack && !busy ? onBack : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: isLast ? 3 : 2,
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
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i < step ? AppColors.amber : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
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
    final radius = BorderRadius.circular(10);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? AppColors.amberTint : Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.amber : Colors.transparent,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                    color: selected ? AppColors.amber : AppColors.grayLight,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Free-text answer box (Figma V2: "Input/Default", 200pt tall).
class AnswerTextField extends StatelessWidget {
  const AnswerTextField({
    super.key,
    required this.onChanged,
    this.initialValue,
  });

  final String? initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return SizedBox(
      height: 200,
      child: TextFormField(
        initialValue: initialValue,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 16, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Your answer here.',
          hintStyle: const TextStyle(fontSize: 16, color: AppColors.hint),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: border(AppColors.border),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.amber, 1.5),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
