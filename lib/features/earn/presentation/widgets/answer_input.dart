import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/earn_models.dart';
import 'question_scaffold.dart';

/// Renders the right control for each of the API's question types — the
/// survey runner and the questions after an ad share it.
class AnswerInput extends StatelessWidget {
  const AnswerInput({
    super.key,
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
        return AnswerTextField(
          initialValue: answer?.textAnswer,
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
