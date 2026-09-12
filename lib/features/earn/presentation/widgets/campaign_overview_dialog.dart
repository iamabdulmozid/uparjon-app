import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/error/failure.dart';
import '../../data/earn_models.dart';
import '../earn_providers.dart';
import '../earn_task_kind.dart';
import 'task_overview_dialog.dart';

/// Overview for a campaign card. Unlike ads and surveys, the copy lives in
/// `GET /mobile/campaigns/{id}` (description, instructions, eligibility), so
/// the dialog loads it while open and only enables Start once it knows the
/// user is eligible.
class CampaignOverviewDialog extends ConsumerWidget {
  const CampaignOverviewDialog({super.key, required this.card});

  final CampaignCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(campaignDetailsProvider(card.id));

    return TaskOverviewDialog(
      canStart: details.value?.eligible ?? false,
      child: details.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            error is Failure ? error.message : 'Could not load this campaign.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.slate),
          ),
        ),
        data: (campaign) {
          final lines = instructionLines(campaign.instructions);
          return TaskOverviewBody(
            kind: EarnTaskKind.campaigns,
            title: campaign.title,
            sections: [
              if (campaign.description?.trim().isNotEmpty ?? false)
                OverviewSection(
                  'About this campaign',
                  text: campaign.description,
                ),
              if (lines.isNotEmpty)
                OverviewSection('Before you start', bullets: lines),
              rewardSection(
                lead: 'Complete this campaign to receive',
                amount: campaign.rewardAmount ?? card.rewardAmount,
                tail:
                    'The reward will be added to your wallet after '
                    'verification',
              ),
              if (!campaign.eligible)
                const OverviewSection(
                  'Not available',
                  text: 'You are not eligible for this campaign right now.',
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Turns free-text instructions into bullet lines: one per line, with any
/// leading "-", "•" or "1." markers the advertiser typed stripped off.
List<String> instructionLines(String? raw) {
  if (raw == null) return const [];
  final marker = RegExp(r'^\s*(?:[-•*]|\d+[.)])\s*');
  return [
    for (final line in raw.split(RegExp(r'\r?\n')))
      if (line.replaceFirst(marker, '').trim() case final text
          when text.isNotEmpty)
        text,
  ];
}
