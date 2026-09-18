import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import 'earn_providers.dart';
import 'earn_task_kind.dart';
import 'widgets/campaign_overview_dialog.dart';
import 'widgets/earn_stat_card.dart';
import 'widgets/earn_task_card.dart';
import 'widgets/task_overview_dialog.dart';

/// One earning category (Figma: "Uparjon - Ad list", "Uparjon - Survey list"):
/// today's earning, the tasks still open, and the ones already completed.
///
/// Tapping a task opens its overview; Start pushes the runner screen.
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key, required this.kind});

  final EarnTaskKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _itemsOf(ref);
    final earnings = ref.watch(earningsSummaryProvider);
    final completed =
        ref.watch(rewardHistoryProvider).value?.items ??
        const <RewardHistoryItem>[];

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          kind.title,
          style: const TextStyle(fontSize: 18, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () async => invalidateEarnFeeds(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: EarnStatCard(
                      child: EarnValueStat(
                        value: earnings.value == null
                            ? '—'
                            : Formatters.takaCompact(earnings.value!.today),
                        label: "Today's Earning",
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: EarnStatCard(
                      child: EarnValueStat(
                        value: items.value == null
                            ? '—'
                            : Formatters.twoDigits(items.value!.length),
                        label: kind.countLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Heading(kind.listHeading),
            const SizedBox(height: 12),
            ...items.when<List<Widget>>(
              // After a task completes the feeds are invalidated; keep the
              // old list on screen until the new one lands.
              skipLoadingOnReload: true,
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  ),
                ),
              ],
              error: (error, _) => [
                EarnListState(
                  message: error is Failure
                      ? error.message
                      : 'Could not load this list.',
                  onRetry: () => invalidateEarnFeeds(ref),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [EarnListState(message: kind.emptyMessage)]
                  : [
                      for (final item in list)
                        EarnTaskCard(
                          title: item.title,
                          icon: kind.icon,
                          iconColor: kind.color,
                          iconBackground: kind.tint,
                          subtitle: item.subtitle,
                          reward: Formatters.rewardOrNull(item.reward),
                          onTap: () => _open(context, item),
                        ),
                    ],
            ),
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _Heading('Completed'),
              const SizedBox(height: 12),
              for (final reward in completed)
                CompletedTaskCard(
                  title: reward.campaignName.isEmpty
                      ? 'Reward'
                      : reward.campaignName,
                  pending: reward.isPending,
                  message: _completedMessage(kind, reward),
                  icon: kind.icon,
                  color: kind.color,
                  tint: kind.tint,
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _completedMessage(EarnTaskKind kind, RewardHistoryItem reward) {
    final amount = reward.rewardAmount;
    final noun = kind.noun.toLowerCase();
    if (reward.isPending) {
      return amount == null
          ? 'Completed! Your reward is pending verification'
          : 'Completed! ${Formatters.taka(amount)} is pending verification';
    }
    return amount == null
        ? 'Completed this $noun successfully!'
        : 'Completed this $noun successfully! and earned '
              '${Formatters.taka(amount)}';
  }

  Future<void> _open(BuildContext context, _TaskItem item) async {
    final start = await showOverviewDialog(context, item.overview);
    if (!start || !context.mounted) return;
    await context.pushNamed(item.route, pathParameters: {'id': item.id});
  }

  AsyncValue<List<_TaskItem>> _itemsOf(WidgetRef ref) => switch (kind) {
    EarnTaskKind.ads =>
      ref
          .watch(adsFeedProvider)
          .whenData((ads) => [for (final ad in ads) _TaskItem.ad(ad)]),
    EarnTaskKind.quizzes =>
      ref
          .watch(quizzesProvider)
          .whenData(
            (quizzes) => [for (final quiz in quizzes) _TaskItem.quiz(quiz)],
          ),
    EarnTaskKind.surveys =>
      ref
          .watch(surveysProvider)
          .whenData(
            (surveys) => [
              for (final survey in surveys) _TaskItem.survey(survey),
            ],
          ),
    EarnTaskKind.campaigns =>
      ref
          .watch(campaignsProvider)
          .whenData(
            (page) => [
              for (final campaign in page.items) _TaskItem.campaign(campaign),
            ],
          ),
  };
}

/// What the list needs from any task type: the card copy, where Start goes,
/// and the overview to show first.
class _TaskItem {
  const _TaskItem({
    required this.id,
    required this.title,
    required this.route,
    required this.overview,
    this.subtitle,
    this.reward,
  });

  final String id;
  final String title;
  final String route;
  final Widget overview;
  final String? subtitle;
  final num? reward;

  factory _TaskItem.ad(VideoAd ad) => _TaskItem(
    id: ad.adId,
    title: ad.title,
    route: Routes.watchAd,
    reward: ad.reward,
    subtitle: ad.duration == null
        ? null
        : Formatters.approxDuration(ad.duration!),
    overview: TaskOverviewDialog(
      child: TaskOverviewBody(
        kind: EarnTaskKind.ads,
        title: ad.title,
        sections: [
          OverviewSection(
            'Before you start',
            bullets: [
              'Watch the video till the end',
              if (ad.question != null) 'Answer the question correctly.',
              "You can't skip the video",
            ],
          ),
          rewardSection(
            lead: ad.question == null
                ? 'Watch the full video to receive'
                : 'Answer all the questions correctly to receive',
            amount: ad.reward,
            tail: 'The reward will be added to your wallet after verification',
          ),
        ],
      ),
    ),
  );

  factory _TaskItem.survey(SurveyCard survey) {
    final count = survey.questionCount;
    final seconds = survey.estimatedSeconds;
    final about = [
      if (count != null) 'There will be $count questions.',
      if (seconds != null)
        'It takes approximately ${Formatters.duration(seconds)} to answer '
            'all the questions.',
    ].join(' ');

    return _TaskItem(
      id: survey.id,
      title: survey.title,
      route: Routes.survey,
      reward: survey.rewardAmount,
      subtitle: seconds != null
          ? Formatters.approxDuration(seconds)
          : count == null
          ? null
          : '$count questions',
      overview: TaskOverviewDialog(
        child: TaskOverviewBody(
          kind: EarnTaskKind.surveys,
          title: survey.title,
          sections: [
            if (about.isNotEmpty)
              OverviewSection('About this survey', text: about),
            const OverviewSection(
              'Before you start',
              bullets: [
                'Answer honestly based on your own opinion',
                'There are no right or wrong answers',
                'Complete the survey in one session',
                'You cannot change your answers after submission',
              ],
            ),
            const OverviewSection(
              'Privacy',
              text:
                  'Your responses are anonymous and will only be used for '
                  'research and analytics purposes',
            ),
            rewardSection(
              lead: 'Complete all the questions successfully to receive',
              amount: survey.rewardAmount,
              tail:
                  'The reward will be added to your wallet after successful '
                  'submission',
            ),
          ],
        ),
      ),
    );
  }

  factory _TaskItem.quiz(QuizCard quiz) {
    final count = quiz.questionCount;
    return _TaskItem(
      id: quiz.id,
      title: quiz.title,
      route: Routes.quiz,
      reward: quiz.rewardAmount,
      subtitle: count == null ? null : '$count questions',
      overview: TaskOverviewDialog(
        child: TaskOverviewBody(
          kind: EarnTaskKind.quizzes,
          title: quiz.title,
          sections: [
            const OverviewSection(
              'Before you start',
              bullets: [
                'Each question has one correct answer',
                'You can not change your answer later',
                'Complete the quiz in one session',
              ],
            ),
            rewardSection(
              lead: 'Answer all the questions correctly to receive',
              amount: quiz.rewardAmount,
              tail:
                  'The reward will be added to your wallet after verification',
            ),
          ],
        ),
      ),
    );
  }

  factory _TaskItem.campaign(CampaignCard campaign) {
    final subtitle = [
      if (campaign.campaignType != null) campaign.campaignType!,
      if (campaign.estimatedSeconds != null)
        Formatters.duration(campaign.estimatedSeconds!),
    ].join(' · ');

    return _TaskItem(
      id: campaign.id,
      title: campaign.title,
      route: Routes.campaign,
      reward: campaign.rewardAmount,
      subtitle: subtitle.isEmpty ? null : subtitle,
      overview: CampaignOverviewDialog(card: campaign),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}
