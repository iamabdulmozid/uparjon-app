import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/earn_models.dart';
import '../data/earn_repository.dart';

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

/// Refreshes every earning list — call after a reward-producing action so the
/// feeds drop what the user just completed.
void invalidateEarnFeeds(WidgetRef ref) {
  ref.invalidate(adsFeedProvider);
  ref.invalidate(quizzesProvider);
  ref.invalidate(surveysProvider);
  ref.invalidate(campaignsProvider);
  ref.invalidate(featuredCampaignsProvider);
}
