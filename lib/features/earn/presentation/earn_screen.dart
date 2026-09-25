import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/failure.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/ui/activity_tile.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import 'earn_providers.dart';
import 'earn_task_kind.dart';
import 'widgets/earn_stat_card.dart';
import 'widgets/opportunity_tile.dart';

/// The Uparjon tab (Figma: "Uparjon") — today's progress, the earning
/// categories, and what the user recently earned.
///
/// Every block has its own provider, so one broken feed (staging's surveys
/// endpoint, for instance) degrades a single tile instead of the screen.
class EarnScreen extends ConsumerWidget {
  const EarnScreen({super.key});

  static const _activityTints = [
    AppColors.amberTint,
    AppColors.purpleTint,
    AppColors.lavenderTint,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = {
      for (final kind in EarnTaskKind.values) kind: watchKindCount(ref, kind),
    };
    final remaining = counts.values.fold(
      0,
      (sum, count) => sum + (count.value ?? 0),
    );
    final tasks = ref.watch(dailyTasksProvider).value;
    final completion = tasks == null ? null : _completionOf(tasks);
    final history = ref.watch(rewardHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Uparjon',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () async => invalidateEarnFeeds(ref),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: EarnStatCard(
                        child: EarnRingStat(
                          progress: completion ?? 0,
                          value: completion == null
                              ? '—'
                              : '${(completion * 100).round()}%',
                          label: 'Task Completed',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: EarnStatCard(
                        child: EarnRingStat(
                          progress: remaining > 0 ? 1 : 0,
                          value: '$remaining',
                          label: 'Remaining Task',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Earning Opportunity'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final kind in EarnTaskKind.values) ...[
                      if (kind != EarnTaskKind.values.first)
                        const SizedBox(width: 12),
                      OpportunityTile(
                        kind: kind,
                        count: counts[kind]!,
                        onTap: () => context.pushNamed(
                          Routes.earnList,
                          pathParameters: {'kind': kind.slug},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Recent Activity'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  ),
                ),
                error: (error, _) => ListStateMessage(
                  message: error is Failure
                      ? error.message
                      : 'Could not load your activity.',
                  onRetry: () => ref.invalidate(rewardHistoryProvider),
                ),
                data: (page) => page.items.isEmpty
                    ? const ListStateMessage(
                        message:
                            'Nothing here yet. Complete a task and it will '
                            'show up.',
                      )
                    : Column(
                        children: [
                          for (final (i, item) in page.items.indexed) ...[
                            if (i > 0) const SizedBox(height: 8),
                            ActivityTile(
                              title: item.campaignName.isEmpty
                                  ? 'Reward'
                                  : item.campaignName,
                              subtitle: item.isPending
                                  ? 'Pending verification'
                                  : 'Reward added to your wallet',
                              amount:
                                  Formatters.rewardOrNull(item.rewardAmount) ??
                                  '',
                              timestamp: item.rewardedAt == null
                                  ? ''
                                  : Formatters.activityTime(item.rewardedAt!),
                              icon: AppAssets.iconTrophy,
                              background:
                                  _activityTints[i % _activityTints.length],
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Share of today's checklist targets that have been hit.
  static double _completionOf(List<DailyTask> tasks) {
    final target = tasks.fold(0, (sum, task) => sum + task.target);
    if (target == 0) return 0;
    final done = tasks.fold(
      0,
      (sum, task) => sum + math.min(task.progress, task.target),
    );
    return done / target;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
