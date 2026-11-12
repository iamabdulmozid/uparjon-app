import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/error/failure.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import 'earn_providers.dart';
import 'earn_task_kind.dart';
import 'widgets/content_item_tile.dart';
import 'widgets/earn_stat_card.dart';
import 'widgets/earn_task_card.dart';

/// One earning category (Figma: "Uparjon - Ad list", "Uparjon - Survey list"):
/// today's earning, the tasks still open, and the ones already completed.
///
/// Ads, quizzes and surveys come from `GET /mobile/content/*`; tapping one
/// opens its overview, and Start pushes the screen that runs it. Tapping a
/// campaign opens the campaign screen with all of its items. Tasks the user
/// already completed stay listed as history, but sit last, carry a Completed
/// badge, and only explain themselves when tapped.
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key, required this.kind});

  final EarnTaskKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _itemsOf(context, ref);
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
                        value: switch (watchKindCount(ref, kind).value) {
                          null => '—',
                          final count => Formatters.twoDigits(count),
                        },
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
                ListStateMessage(
                  message: error is Failure
                      ? error.message
                      : 'Could not load this list.',
                  onRetry: () => invalidateEarnFeeds(ref),
                ),
              ],
              data: (cards) => cards.isEmpty
                  ? [ListStateMessage(message: kind.emptyMessage)]
                  : cards,
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
                  rejected: reward.isRejected,
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
          ? 'Completed! Your reward is under review'
          : 'Completed! ${Formatters.taka(amount)} is under review';
    }
    if (reward.isRejected) {
      return 'Completed, but the reward was not approved after review';
    }
    return amount == null
        ? 'Completed this $noun successfully!'
        : 'Completed this $noun successfully! and earned '
              '${Formatters.taka(amount)}';
  }

  /// Open tasks first, completed ones after, each group in list order.
  AsyncValue<List<Widget>> _itemsOf(BuildContext context, WidgetRef ref) {
    if (kind == EarnTaskKind.campaigns) {
      return ref.watch(campaignsProvider).whenData((page) {
        final cards = [
          ...page.items.where((c) => !c.isCompleted),
          ...page.items.where((c) => c.isCompleted),
        ];
        return [
          for (final campaign in cards)
            EarnTaskCard(
              title: campaign.title,
              icon: kind.icon,
              iconColor: kind.color,
              iconBackground: kind.tint,
              subtitle: _campaignSubtitle(campaign),
              reward: Formatters.rewardOrNull(campaign.rewardAmount),
              completed: campaign.isCompleted,
              // Completed campaigns still open: their items are the record
              // of what the user did.
              onTap: () => context.pushNamed(
                Routes.campaign,
                pathParameters: {'id': campaign.id},
              ),
            ),
        ];
      });
    }

    return ref.watch(contentListProvider(kind)).whenData((page) {
      final items = [
        ...page.items.where((i) => !i.isCompleted),
        ...page.items.where((i) => i.isCompleted),
      ];
      return [
        for (final item in items)
          ContentItemCard(
            item: item,
            onTap: () => openContentItem(context, item),
          ),
      ];
    });
  }

  static String? _campaignSubtitle(CampaignCard campaign) {
    final subtitle = [
      ?campaign.contentTypeLabel,
      if (campaign.estimatedSeconds != null)
        Formatters.duration(campaign.estimatedSeconds!),
    ].join(' · ');
    return subtitle.isEmpty ? null : subtitle;
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
