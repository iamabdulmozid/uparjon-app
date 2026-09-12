import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/ui/app_button.dart';
import '../../../../core/utils/formatters.dart';
import '../earn_task_kind.dart';

/// Opens [dialog] and resolves to true when the user tapped Start.
Future<bool> showOverviewDialog(BuildContext context, Widget dialog) async {
  final started = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (_) => dialog,
  );
  return started ?? false;
}

/// One block of an overview: a heading with a paragraph and/or bullets.
class OverviewSection {
  const OverviewSection(
    this.heading, {
    this.text,
    this.bullets = const [],
    this.emphasis,
  });

  final String heading;
  final String? text;
  final List<String> bullets;

  /// A substring of [text] to render bold — the reward amount.
  final String? emphasis;
}

/// The "Reward" block: `<lead> ৳10.00. <tail>` with the amount in bold, or
/// just the tail when the API sent no amount.
OverviewSection rewardSection({
  required String lead,
  required num? amount,
  required String tail,
}) {
  if (amount == null) return OverviewSection('Reward', text: tail);
  final money = Formatters.taka(amount);
  return OverviewSection(
    'Reward',
    text: '$lead $money. $tail',
    emphasis: money,
  );
}

/// The "Overview" popup shown before a task starts (Figma: "Ad overview",
/// "Survey overview"). Pops `true` for Start and `false` for Back or close.
class TaskOverviewDialog extends StatelessWidget {
  const TaskOverviewDialog({
    super.key,
    required this.child,
    this.canStart = true,
  });

  final Widget child;

  /// False keeps the Start button disabled (e.g. an ineligible campaign).
  final bool canStart;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Positioned(
                  right: 4,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: child,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.soft,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Start',
                    onPressed: canStart
                        ? () => Navigator.of(context).pop(true)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon, title and sections inside a [TaskOverviewDialog].
class TaskOverviewBody extends StatelessWidget {
  const TaskOverviewBody({
    super.key,
    required this.kind,
    required this.title,
    required this.sections,
  });

  final EarnTaskKind kind;
  final String title;
  final List<OverviewSection> sections;

  static const TextStyle _bodyStyle = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: AppColors.slate,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kind.tint,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  kind.icon,
                  width: 24,
                  colorFilter: ColorFilter.mode(kind.color, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),
        for (final section in sections) ...[
          const SizedBox(height: 16),
          Text(
            section.heading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          if (section.text != null)
            _Paragraph(text: section.text!, emphasis: section.emphasis),
          for (final bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: _bodyStyle),
                  Expanded(child: Text(bullet, style: _bodyStyle)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text, this.emphasis});

  final String text;
  final String? emphasis;

  @override
  Widget build(BuildContext context) {
    final bold = emphasis;
    final at = bold == null ? -1 : text.indexOf(bold);
    if (bold == null || at < 0) {
      return Text(text, style: TaskOverviewBody._bodyStyle);
    }

    return Text.rich(
      TextSpan(
        style: TaskOverviewBody._bodyStyle,
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: bold,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          TextSpan(text: text.substring(at + bold.length)),
        ],
      ),
    );
  }
}
