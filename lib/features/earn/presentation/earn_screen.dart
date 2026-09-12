import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import 'earn_providers.dart';
import 'widgets/earn_task_card.dart';

/// The Uparjon tab — everything the user can do to earn.
///
/// Ads, quizzes, surveys and campaigns each come from their own endpoint, so
/// they load independently: one failing feed does not blank the others.
class EarnScreen extends ConsumerWidget {
  const EarnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
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
          // Four fixed tabs share the width: on a 412pt phone a scrollable
          // bar pushed "Campaigns" off-screen entirely.
          bottom: const TabBar(
            labelColor: AppColors.charcoal,
            unselectedLabelColor: AppColors.slate,
            indicatorColor: AppColors.amber,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            labelPadding: EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              Tab(text: 'Ads'),
              Tab(text: 'Surveys'),
              Tab(text: 'Quizzes'),
              Tab(text: 'Campaigns'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_AdsTab(), _SurveysTab(), _QuizzesTab(), _CampaignsTab()],
        ),
      ),
    );
  }
}

/// Wraps a feed in pull-to-refresh with shared loading/empty/error states.
///
/// Takes the resolved [AsyncValue] rather than the provider itself so each
/// tab stays responsible for its own refresh.
class _Feed<T> extends StatelessWidget {
  const _Feed({
    required this.async,
    required this.onRefresh,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final AsyncValue<List<T>> async;
  final VoidCallback onRefresh;
  final String emptyMessage;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.amber,
      onRefresh: () async => onRefresh(),
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EarnListState(
              message: error is Failure
                  ? error.message
                  : 'Could not load this list.',
              onRetry: onRefresh,
            ),
          ],
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: items.isEmpty
              ? [EarnListState(message: emptyMessage)]
              : [for (final item in items) itemBuilder(context, item)],
        ),
      ),
    );
  }
}

class _AdsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Feed<VideoAd>(
      async: ref.watch(adsFeedProvider),
      onRefresh: () => ref.invalidate(adsFeedProvider),
      emptyMessage: 'No ads available right now.\nCheck back a little later.',
      itemBuilder: (context, ad) => EarnTaskCard(
        title: ad.title,
        icon: AppAssets.iconVideo,
        subtitle: ad.duration == null
            ? null
            : 'Takes approximately ${Formatters.duration(ad.duration!)}',
        reward: Formatters.rewardOrNull(ad.reward),
        onTap: () =>
            context.pushNamed(Routes.watchAd, pathParameters: {'id': ad.adId}),
      ),
    );
  }
}

class _SurveysTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Feed<SurveyCard>(
      async: ref.watch(surveysProvider),
      onRefresh: () => ref.invalidate(surveysProvider),
      emptyMessage: 'No surveys available right now.',
      itemBuilder: (context, survey) => EarnTaskCard(
        title: survey.title,
        icon: AppAssets.iconClipboard,
        subtitle: [
          if (survey.questionCount != null) '${survey.questionCount} questions',
          if (survey.estimatedSeconds != null)
            Formatters.duration(survey.estimatedSeconds!),
        ].join(' · '),
        reward: Formatters.rewardOrNull(survey.rewardAmount),
        onTap: () =>
            context.pushNamed(Routes.survey, pathParameters: {'id': survey.id}),
      ),
    );
  }
}

class _QuizzesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Feed<QuizCard>(
      async: ref.watch(quizzesProvider),
      onRefresh: () => ref.invalidate(quizzesProvider),
      emptyMessage: 'No quizzes available right now.',
      itemBuilder: (context, quiz) => EarnTaskCard(
        title: quiz.title,
        icon: AppAssets.menuTutorial,
        subtitle: quiz.questionCount == null
            ? null
            : '${quiz.questionCount} questions',
        reward: Formatters.rewardOrNull(quiz.rewardAmount),
        onTap: () =>
            context.pushNamed(Routes.quiz, pathParameters: {'id': quiz.id}),
      ),
    );
  }
}

/// Campaigns arrive paged, so this tab unwraps the page before reusing [_Feed].
class _CampaignsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campaignsProvider);

    return RefreshIndicator(
      color: AppColors.amber,
      onRefresh: () async => ref.invalidate(campaignsProvider),
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EarnListState(
              message: error is Failure
                  ? error.message
                  : 'Could not load campaigns.',
              onRetry: () => ref.invalidate(campaignsProvider),
            ),
          ],
        ),
        data: (page) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: page.items.isEmpty
              ? [const EarnListState(message: 'No campaigns available yet.')]
              : [
                  for (final campaign in page.items)
                    EarnTaskCard(
                      title: campaign.title,
                      icon: AppAssets.iconTrophy,
                      subtitle: [
                        if (campaign.campaignType != null)
                          campaign.campaignType!,
                        if (campaign.estimatedSeconds != null)
                          Formatters.duration(campaign.estimatedSeconds!),
                      ].join(' · '),
                      reward: Formatters.rewardOrNull(campaign.rewardAmount),
                      onTap: () => context.pushNamed(
                        Routes.campaign,
                        pathParameters: {'id': campaign.id},
                      ),
                    ),
                ],
        ),
      ),
    );
  }
}
