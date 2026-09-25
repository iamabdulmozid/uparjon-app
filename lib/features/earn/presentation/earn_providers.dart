import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallet/presentation/wallet_providers.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_task_kind.dart';

/// Watchable video ads (`GET /mobile/ads/feed`).
final adsFeedProvider = FutureProvider.autoDispose<List<VideoAd>>(
  (ref) => ref.watch(earnRepositoryProvider).adsFeed(),
);

/// Available quizzes (`GET /mobile/quizzes`).
final quizzesProvider = FutureProvider.autoDispose<List<QuizCard>>(
  (ref) => ref.watch(earnRepositoryProvider).quizzes(),
);

/// Available surveys (`GET /mobile/surveys`).
final surveysProvider = FutureProvider.autoDispose<List<SurveyCard>>(
  (ref) => ref.watch(earnRepositoryProvider).surveys(),
);

/// First page of campaigns (`GET /mobile/campaigns`).
final campaignsProvider = FutureProvider.autoDispose<Paged<CampaignCard>>(
  (ref) => ref.watch(earnRepositoryProvider).campaigns(),
);

/// Featured campaigns, shown above the list.
final featuredCampaignsProvider =
    FutureProvider.autoDispose<List<CampaignCard>>(
      (ref) => ref.watch(earnRepositoryProvider).featuredCampaigns(),
    );

final campaignDetailsProvider = FutureProvider.autoDispose
    .family<CampaignDetails, String>(
      (ref, id) => ref.watch(earnRepositoryProvider).campaign(id),
    );

final quizDetailsProvider = FutureProvider.autoDispose
    .family<QuizDetails, String>(
      (ref, id) => ref.watch(earnRepositoryProvider).quiz(id),
    );

final surveyDetailsProvider = FutureProvider.autoDispose
    .family<SurveyDetails, String>(
      (ref, id) => ref.watch(earnRepositoryProvider).survey(id),
    );

/// Today / week / month / lifetime earnings — the "Today's Earning" stat.
///
/// Delegates to the wallet feature, which owns the endpoint, so the figure
/// here and the one on the Wallet tab can never disagree.
final earningsSummaryProvider = FutureProvider.autoDispose<EarningsSummary>(
  (ref) => ref.watch(walletEarningsProvider.future),
);

/// First page of completed rewards — the "Completed" cards and the activity
/// list.
final rewardHistoryProvider =
    FutureProvider.autoDispose<Paged<RewardHistoryItem>>(
      (ref) => ref.watch(earnRepositoryProvider).rewardHistory(),
    );

/// Today's checklist — the "Task Completed" ring.
final dailyTasksProvider = FutureProvider.autoDispose<List<DailyTask>>(
  (ref) => ref.watch(earnRepositoryProvider).dailyTasks(),
);

/// How many items a category currently offers — the landing tile badge and
/// the "Remaining" stat.
AsyncValue<int> watchKindCount(
  WidgetRef ref,
  EarnTaskKind kind,
) => switch (kind) {
  EarnTaskKind.ads => ref.watch(adsFeedProvider).whenData((ads) => ads.length),
  EarnTaskKind.quizzes =>
    ref.watch(quizzesProvider).whenData((quizzes) => quizzes.length),
  EarnTaskKind.surveys =>
    ref.watch(surveysProvider).whenData((surveys) => surveys.length),
  EarnTaskKind.campaigns =>
    ref
        .watch(campaignsProvider)
        .whenData((page) => math.max(page.totalElements, page.items.length)),
};

/// Refreshes every earning list and stat — call after a reward-producing
/// action so the feeds drop what the user just completed and the totals move.
void invalidateEarnFeeds(WidgetRef ref) {
  ref.invalidate(adsFeedProvider);
  ref.invalidate(quizzesProvider);
  ref.invalidate(surveysProvider);
  ref.invalidate(campaignsProvider);
  ref.invalidate(featuredCampaignsProvider);
  ref.invalidate(rewardHistoryProvider);
  ref.invalidate(dailyTasksProvider);
  // A reward moves the balance and writes a ledger row, so the wallet is
  // stale too — Home's balance card would otherwise keep the old figure
  // until the app restarted.
  invalidateWallet(ref);
}
