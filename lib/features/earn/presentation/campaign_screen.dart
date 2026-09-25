import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/error/failure.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../data/earn_models.dart';
import '../data/earn_repository.dart';
import 'earn_providers.dart';
import 'widgets/campaign_overview_dialog.dart';
import 'widgets/earn_popup.dart';
import 'widgets/preparing_view.dart';

/// Campaign run (API lifecycle: start → complete → fraud validation → reward).
///
/// Reached from the overview's Start button, so the session is opened on
/// arrival. Completion only enters validation, which is why the closing
/// popup promises the reward "after verification" rather than right away.
class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

enum _Phase { starting, running, completing, result }

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  /// Codes that mean the card the user tapped is out of date.
  static const _stale = {
    ApiErrorCodes.campaignNotEligible,
    ApiErrorCodes.duplicateRequest,
  };

  _Phase _phase = _Phase.starting;
  Failure? _startFailure;
  Failure? _completeFailure;
  bool _popupHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.starting;
      _startFailure = null;
    });
    try {
      await ref.read(earnRepositoryProvider).startCampaign(widget.campaignId);
      if (!mounted) return;
      setState(() => _phase = _Phase.running);
    } catch (error) {
      if (!mounted) return;
      final failure = Failure.from(error);
      if (_stale.contains(failure.code)) {
        _leaveStale(failure);
        return;
      }
      setState(() => _startFailure = failure);
    }
  }

  /// Ineligible or already done: refresh the feeds and send the user back.
  void _leaveStale(Failure failure) {
    SnackbarService.showFailure(failure);
    invalidateEarnFeeds(ref);
    ref.invalidate(campaignDetailsProvider(widget.campaignId));
    if (context.canPop()) context.pop();
  }

  Future<void> _complete() async {
    setState(() {
      _phase = _Phase.completing;
      _completeFailure = null;
      _popupHidden = false;
    });
    try {
      await ref
          .read(earnRepositoryProvider)
          .completeCampaign(widget.campaignId);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.result;
        _popupHidden = false;
      });
      invalidateEarnFeeds(ref);
    } catch (error) {
      if (!mounted) return;
      final failure = Failure.from(error);
      if (_stale.contains(failure.code)) {
        _leaveStale(failure);
        return;
      }
      setState(() {
        _completeFailure = failure;
        _phase = _Phase.result;
        _popupHidden = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFailure = _startFailure;
    final starting = _phase == _Phase.starting;

    final Widget body;
    if (starting) {
      body = startFailure == null
          ? const PreparingView(
              title: 'Starting Campaign',
              subtitle: 'Please wait a moment',
            )
          : ListStateMessage(
              message: startFailure.message,
              onRetry: () => unawaited(_start()),
            );
    } else {
      body = ref
          .watch(campaignDetailsProvider(widget.campaignId))
          .when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (error, _) => ListStateMessage(
              message: error is Failure
                  ? error.message
                  : 'Could not load this campaign.',
              onRetry: () =>
                  ref.invalidate(campaignDetailsProvider(widget.campaignId)),
            ),
            data: (campaign) => _CampaignBody(
              campaign: campaign,
              busy: _phase == _Phase.completing,
              onComplete: _phase == _Phase.running
                  ? () => unawaited(_complete())
                  : null,
            ),
          );
    }

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: starting && startFailure == null
          ? null
          : AppBar(
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (_phase == _Phase.completing && !_popupHidden)
            EarnPopup(
              illustration: AppAssets.illustrationVerifying,
              title: 'Verifying',
              message: 'Please wait while we verify your completion',
              onClose: () => setState(() => _popupHidden = true),
            ),
          if (_phase == _Phase.result && !_popupHidden) _resultPopup(context),
        ],
      ),
    );
  }

  Widget _resultPopup(BuildContext context) {
    final failure = _completeFailure;
    if (failure != null) {
      void backToRunning() => setState(() {
        _phase = _Phase.running;
        _completeFailure = null;
      });
      return EarnPopup(
        illustration: AppAssets.illustrationNotRewarded,
        title: 'Not completed',
        message: failure.message,
        actionLabel: 'Try again',
        onAction: backToRunning,
        onClose: backToRunning,
      );
    }
    return EarnPopup(
      illustration: AppAssets.illustrationCongratulations,
      title: 'Completed!',
      message: 'Your reward will be added to your wallet after verification.',
      actionLabel: 'Continue',
      onAction: () => context.pop(),
      onClose: () => context.pop(),
    );
  }
}

class _CampaignBody extends StatelessWidget {
  const _CampaignBody({
    required this.campaign,
    required this.busy,
    required this.onComplete,
  });

  final CampaignDetails campaign;
  final bool busy;

  /// Null once the campaign has been completed, so the button cannot fire
  /// a second time from behind the result popup.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final steps = instructionLines(campaign.instructions);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (campaign.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                    color: AppColors.greenDeep,
                  ),
                ),
              if (campaign.estimatedDuration != null) ...[
                const SizedBox(width: 12),
                Text(
                  Formatters.approxDuration(campaign.estimatedDuration!),
                  style: const TextStyle(fontSize: 13, color: AppColors.hint),
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
          if (steps.isNotEmpty) ...[
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
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: _stepStyle),
                    Expanded(child: Text(step, style: _stepStyle)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 32),
          if (!campaign.eligible)
            const Text(
              'You are not eligible for this campaign right now.',
              style: TextStyle(fontSize: 14, color: AppColors.slate),
            )
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

  static const TextStyle _stepStyle = TextStyle(
    fontSize: 15,
    height: 1.6,
    color: AppColors.slate,
  );
}
