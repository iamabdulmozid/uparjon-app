import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallet/presentation/wallet_providers.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_task_kind.dart';

/// The Ads, Quiz or Survey list (`GET /mobile/content/{ads,quizzes,surveys}`).
/// Campaigns have their own cards — see [campaignsProvider].
final contentListProvider = FutureProvider.autoDispose
    .family<Paged<ContentItem>, EarnTaskKind>((ref, kind) {
      final repo = ref.watch(earnRepositoryProvider);
      return switch (kind) {
        EarnTaskKind.ads => repo.contentAds(),
        EarnTaskKind.quizzes => repo.contentQuizzes(),
        EarnTaskKind.surveys => repo.contentSurveys(),
        EarnTaskKind.campaigns => throw ArgumentError.value(
          kind,
          'kind',
          'Campaigns are listed by campaignsProvider',
        ),
      };
    });

/// One campaign item with its questions (`GET /mobile/content/{id}`).
final contentDetailProvider = FutureProvider.autoDispose
    .family<ContentDetail, String>(
      (ref, id) => ref.watch(earnRepositoryProvider).contentItem(id),
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

/// A campaign's items and the user's progress on them
/// (`GET /mobile/campaigns/{id}/items`).
final campaignItemsProvider = FutureProvider.autoDispose
    .family<CampaignContent, String>(
      (ref, id) => ref.watch(earnRepositoryProvider).campaignItems(id),
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
///
/// Completed items stay in their lists as history; only the open ones are
/// pending. Pages not loaded yet count as open.
AsyncValue<int> watchKindCount(WidgetRef ref, EarnTaskKind kind) =>
    switch (kind) {
      EarnTaskKind.campaigns =>
        ref
            .watch(campaignsProvider)
            .whenData((page) => _openCount(page, (c) => !c.isCompleted)),
      _ =>
        ref
            .watch(contentListProvider(kind))
            .whenData((page) => _openCount(page, (item) => item.canStart)),
    };

int _openCount<T>(Paged<T> page, bool Function(T) open) =>
    page.items.where(open).length +
    math.max(0, page.totalElements - page.items.length);

/// Refreshes every earning list and stat — call after a reward-producing
/// action so the lists show what the user just completed and the totals
/// move. The server does not cache these lists, and an answer can change
/// which campaigns target the user, so everything is re-fetched.
void invalidateEarnFeeds(WidgetRef ref) {
  ref.invalidate(contentListProvider);
  ref.invalidate(contentDetailProvider);
  ref.invalidate(campaignsProvider);
  ref.invalidate(featuredCampaignsProvider);
  ref.invalidate(campaignItemsProvider);
  ref.invalidate(rewardHistoryProvider);
  ref.invalidate(dailyTasksProvider);
  // A reward moves the balance and writes a ledger row, so the wallet is
  // stale too — Home's balance card would otherwise keep the old figure
  // until the app restarted.
  invalidateWallet(ref);
}
