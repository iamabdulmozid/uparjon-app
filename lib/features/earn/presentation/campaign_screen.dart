import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_env.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/error/failure.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import 'earn_providers.dart';
import 'widgets/content_item_tile.dart';

/// One campaign with all of its ads, quizzes and surveys
/// (`GET /mobile/campaigns/{id}/items`). Each item is done once, on its own;
/// the header counts how many are finished.
///
/// The campaign screen lists every item, unavailable ones included, so
/// those are greyed out with the server's reason rather than hidden.
class CampaignScreen extends ConsumerWidget {
  const CampaignScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campaignItemsProvider(campaignId));
    void reload() => ref.invalidate(campaignItemsProvider(campaignId));

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Campaign',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.ink,
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        // Keep the items on screen while they refresh after a submit.
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (error, _) {
          final failure = Failure.from(error);
          // Not live any more, and the user never took part.
          final gone = failure.code == ApiErrorCodes.notFound;
          return ListStateMessage(
            message: gone
                ? 'This campaign is no longer available.'
                : failure.message,
            onRetry: gone ? null : reload,
          );
        },
        data: (campaign) => RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _Header(campaign: campaign),
              if (campaign.isEmpty)
                const ListStateMessage(
                  message: 'This campaign has nothing to do right now.',
                ),
              for (final (heading, items) in [
                ('Ads', campaign.ads),
                ('Quizzes', campaign.quizzes),
                ('Surveys', campaign.surveys),
              ])
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in items)
                    ContentItemCard(
                      item: item,
                      onTap: () => openContentItem(context, item),
                    ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner, title, copy, end date and "1 of 3 done".
class _Header extends StatelessWidget {
  const _Header({required this.campaign});

  final CampaignContent campaign;

  @override
  Widget build(BuildContext context) {
    final banner = AppEnv.resolveMediaUrl(campaign.bannerUrl);
    final total = campaign.totalItems;
    final done = campaign.completedItems.clamp(0, total);
    final endAt = campaign.endAt;
    final description = campaign.description?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                banner,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.amberTint),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          campaign.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: AppColors.ink,
          ),
        ),
        if (endAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Ends ${Formatters.activityTime(endAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.hint),
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.slate,
            ),
          ),
        ],
        if (total > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '$done of $total done',
                style: const TextStyle(fontSize: 13, color: AppColors.slate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 6,
              color: AppColors.amber,
              backgroundColor: AppColors.amberTint,
            ),
          ),
        ],
      ],
    );
  }
}
