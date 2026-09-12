import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/error/failure.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';

/// Campaign overview and run (Figma: "Uparjon - Ad Overview").
///
/// Follows the documented lifecycle: start → complete → pending reward.
/// Completion enters fraud validation, so the wallet is not credited instantly.
class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  bool _busy = false;
  bool _started = false;
  bool _completed = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref.read(earnRepositoryProvider).startCampaign(widget.campaignId);
      if (!mounted) return;
      setState(() => _started = true);
    } catch (error) {
      if (!mounted) return;
      _handleFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(earnRepositoryProvider)
          .completeCampaign(widget.campaignId);
      if (!mounted) return;
      setState(() => _completed = true);
      invalidateEarnFeeds(ref);
    } catch (error) {
      if (!mounted) return;
      _handleFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ineligibility and duplicate completion both mean "this card is stale",
  /// so the feed is refreshed and the user sent back.
  void _handleFailure(Object error) {
    final failure = Failure.from(error);
    SnackbarService.showFailure(failure);

    const stale = {'CAMPAIGN_NOT_ELIGIBLE', ApiErrorCodes.duplicateRequest};
    if (stale.contains(failure.code)) {
      invalidateEarnFeeds(ref);
      ref.invalidate(campaignDetailsProvider(widget.campaignId));
      if (context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(campaignDetailsProvider(widget.campaignId));

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is Failure
                  ? error.message
                  : 'Could not load this campaign.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate),
            ),
          ),
        ),
        data: (campaign) => _CampaignBody(
          campaign: campaign,
          busy: _busy,
          started: _started,
          completed: _completed,
          onStart: _start,
          onComplete: _complete,
          onDone: () => context.pop(),
        ),
      ),
    );
  }
}

class _CampaignBody extends StatelessWidget {
  const _CampaignBody({
    required this.campaign,
    required this.busy,
    required this.started,
    required this.completed,
    required this.onStart,
    required this.onComplete,
    required this.onDone,
  });

  final CampaignDetails campaign;
  final bool busy;
  final bool started;
  final bool completed;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (campaign.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  campaign.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.surface),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            campaign.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (campaign.rewardAmount != null)
                Text(
                  'Earn ${Formatters.taka(campaign.rewardAmount!)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF005B3D),
                  ),
                ),
              if (campaign.estimatedDuration != null) ...[
                const SizedBox(width: 12),
                Text(
                  Formatters.duration(campaign.estimatedDuration!),
                  style: const TextStyle(fontSize: 14, color: AppColors.slate),
                ),
              ],
            ],
          ),
          if (campaign.description != null) ...[
            const SizedBox(height: 20),
            Text(
              campaign.description!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.slate,
              ),
            ),
          ],
          if (campaign.instructions != null) ...[
            const SizedBox(height: 20),
            const Text(
              'How it works',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              campaign.instructions!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.slate,
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (completed) ...[
            const _PendingReward(),
            const SizedBox(height: 20),
            AppButton(label: 'Done', onPressed: onDone),
          ] else if (!campaign.eligible)
            const Text(
              'You are not eligible for this campaign right now.',
              style: TextStyle(fontSize: 14, color: AppColors.slate),
            )
          else if (!started)
            AppButton(label: 'Start', loading: busy, onPressed: onStart)
          else
            AppButton(
              label: 'Mark as Complete',
              loading: busy,
              onPressed: onComplete,
            ),
        ],
      ),
    );
  }
}

class _PendingReward extends StatelessWidget {
  const _PendingReward();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_bottom, color: AppColors.amber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reward pending review. It lands in your wallet once the '
              'campaign passes validation.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
