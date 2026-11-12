import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/services/snackbar_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/earn_models.dart';
import '../earn_task_kind.dart';
import 'earn_task_card.dart';
import 'task_overview_dialog.dart';

/// The card for one ad, quiz or survey — in its category list and on the
/// campaign screen alike, since both show the same item.
class ContentItemCard extends StatelessWidget {
  const ContentItemCard({super.key, required this.item, required this.onTap});

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = EarnTaskKind.of(item.kind);
    return EarnTaskCard(
      title: item.title,
      icon: kind.icon,
      iconColor: kind.color,
      iconBackground: kind.tint,
      subtitle: _subtitle,
      reward: Formatters.rewardOrNull(item.reward),
      completed: item.isCompleted,
      unavailable: item.canStart
          ? null
          : item.unavailableMessage ?? 'Not available right now',
      onTap: onTap,
    );
  }

  String? get _subtitle {
    final seconds = item.durationSeconds ?? 0;
    final count = item.questionCount;
    if (item.progress == ContentProgress.answersPending) {
      return 'Watched · answers pending';
    }
    if (item.hasQuestions && count > 0) {
      return count == 1 ? '1 question' : '$count questions';
    }
    return seconds > 0 ? Formatters.approxDuration(seconds) : null;
  }
}

/// Opens [item]: done items and ones the user cannot do explain themselves,
/// the rest show their overview and, on Start, the screen that runs them.
///
/// Resolves once the user is back, so the caller can refresh.
Future<void> openContentItem(BuildContext context, ContentItem item) async {
  if (item.isCompleted) {
    SnackbarService.showInfo(EarnTaskKind.of(item.kind).alreadyClaimedMessage);
    return;
  }
  if (!item.canStart) {
    SnackbarService.showInfo(
      item.unavailableMessage ?? 'This is not available right now.',
    );
    return;
  }

  final start = await showOverviewDialog(context, ContentItemOverview(item));
  if (!start || !context.mounted) return;

  final route = switch ((item.source, item.kind)) {
    (ContentSource.standalone, ContentKind.quiz) => Routes.quiz,
    (ContentSource.standalone, ContentKind.survey) => Routes.survey,
    _ => Routes.contentItem,
  };
  await context.pushNamed(route, pathParameters: {'id': item.id});
}

/// The overview shown before an item starts (Figma: "Ad overview", "Survey
/// overview").
class ContentItemOverview extends StatelessWidget {
  const ContentItemOverview(this.item, {super.key});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final kind = EarnTaskKind.of(item.kind);
    return TaskOverviewDialog(
      child: TaskOverviewBody(
        kind: kind,
        title: item.title,
        sections: [
          if (item.description?.trim().isNotEmpty ?? false)
            OverviewSection('About', text: item.description!.trim()),
          OverviewSection('Before you start', bullets: _rules),
          rewardSection(
            lead: _rewardLead,
            amount: item.reward,
            tail: 'The reward will be added to your wallet',
          ),
        ],
      ),
    );
  }

  bool get _hasMedia =>
      !item.isStandalone && (item.mediaUrl?.isNotEmpty ?? false);

  String get _media => item.isImage ? 'image' : 'video';

  List<String> get _rules => [
    if (item.progress == ContentProgress.answersPending)
      'You already watched this — answer the questions to finish'
    else if (_hasMedia) ...[
      'Watch the $_media till the end',
      "You can't skip the $_media",
    ],
    ...switch (item.kind) {
      ContentKind.ad => const <String>[],
      ContentKind.quiz => [
        'Answer every question',
        'You get one try — a failed quiz cannot be retaken',
      ],
      ContentKind.survey => const [
        'Answer every question honestly',
        'There are no right or wrong answers',
        'You cannot change your answers after submission',
      ],
    },
  ];

  String get _rewardLead {
    if (item.paysPerQuestion) return 'Each answer pays on its own, up to';
    return switch (item.kind) {
      ContentKind.ad => 'Complete the ad to receive',
      ContentKind.quiz => switch (_passingScore) {
        100 => 'Answer all the questions correctly to receive',
        final score => 'Score at least $score% to receive',
      },
      ContentKind.survey => 'Answer all the questions to receive',
    };
  }

  /// Null means 100 for a campaign quiz; a standalone quiz pays from 60%.
  int get _passingScore => item.passingScore ?? (item.isStandalone ? 60 : 100);
}
