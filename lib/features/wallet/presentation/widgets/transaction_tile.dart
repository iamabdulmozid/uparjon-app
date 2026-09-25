import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/activity_tile.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/wallet_models.dart';

/// One ledger row, rendered as the shared [ActivityTile].
///
/// The wallet owns this mapping because it owns the model; Home's Recent
/// Activity reuses it so the same transaction never renders two ways.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, this.tint});

  final WalletTransaction transaction;

  /// Overrides the kind's own tint — Home alternates tints down the list.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(transaction.kind);

    return ActivityTile(
      title: look.label,
      subtitle: _subtitleOf(transaction),
      amount: Formatters.signedTaka(transaction.amount),
      timestamp: transaction.createdAt == null
          ? ''
          : Formatters.activityTime(transaction.createdAt!),
      icon: look.icon,
      background: tint ?? look.tint,
      amountColor: switch (transaction) {
        _ when transaction.isFailed => AppColors.slate,
        _ when transaction.isPending => AppColors.warning,
        _ when transaction.isDebit => AppColors.dangerText,
        _ => AppColors.greenDeep,
      },
    );
  }

  /// Why the money moved, not the server's raw description — that text runs
  /// long ("Completed Survey: National Consumer … 17897941198473658") and
  /// would be ellipsized to noise. Status comes first when it is not settled.
  static String _subtitleOf(WalletTransaction t) {
    if (t.isPending) return 'Pending verification';
    if (t.isFailed) return 'Could not be completed';
    return switch (t.kind) {
      WalletActivityKind.ad => 'Watched a video ad',
      WalletActivityKind.survey => 'Completed a survey',
      WalletActivityKind.quiz => 'Completed a quiz',
      WalletActivityKind.campaign => 'Completed a campaign',
      WalletActivityKind.withdrawal => 'Paid out from your wallet',
      WalletActivityKind.other =>
        t.description.isEmpty ? 'Added to your wallet' : t.description,
    };
  }

  static ({String label, String icon, Color tint}) _lookOf(
    WalletActivityKind kind,
  ) => switch (kind) {
    WalletActivityKind.ad => (
      label: 'Video Ad',
      icon: AppAssets.iconVideo,
      tint: AppColors.amberTint,
    ),
    WalletActivityKind.survey => (
      label: 'Survey',
      icon: AppAssets.iconClipboard,
      tint: AppColors.purpleTint,
    ),
    WalletActivityKind.quiz => (
      label: 'Quiz',
      icon: AppAssets.iconNotebook,
      tint: AppColors.lavenderTint,
    ),
    WalletActivityKind.campaign => (
      label: 'Campaign',
      icon: AppAssets.iconTrophy,
      tint: AppColors.greenTint,
    ),
    WalletActivityKind.withdrawal => (
      label: 'Withdrawal',
      icon: AppAssets.iconUpload,
      tint: AppColors.blueTint,
    ),
    WalletActivityKind.other => (
      label: 'Reward',
      icon: AppAssets.iconWallet,
      tint: AppColors.amberTint,
    ),
  };
}
