/// Models for the wallet endpoints: balance, transactions, earnings.
///
/// Field names mirror what the live API sends.
/// `docs/mobile-api-specification.md` names a few of them differently
/// (`balance`, `pendingAmount`); those are read as fallbacks so either shape
/// parses. Money arrives as a number and is kept as [num] — the client never
/// does arithmetic on it, only formats it.
library;

/// Balance summary (`GET /mobile/wallet/overview`).
///
/// The same shape rides inside the home feed's `wallet` block, where only the
/// first three fields are present — the rest default to zero.
class WalletOverview {
  const WalletOverview({
    required this.availableBalance,
    required this.pendingBalance,
    required this.lifetimeEarnings,
    required this.totalWithdrawn,
    required this.pendingRewards,
    required this.completedRewards,
  });

  /// What the user can withdraw right now.
  final num availableBalance;

  /// Earned but still held by fraud validation.
  final num pendingBalance;
  final num lifetimeEarnings;
  final num totalWithdrawn;
  final int pendingRewards;
  final int completedRewards;

  static const empty = WalletOverview(
    availableBalance: 0,
    pendingBalance: 0,
    lifetimeEarnings: 0,
    totalWithdrawn: 0,
    pendingRewards: 0,
    completedRewards: 0,
  );

  factory WalletOverview.fromJson(Map<String, dynamic> json) => WalletOverview(
    availableBalance: (json['availableBalance'] ?? json['balance']) as num? ?? 0,
    pendingBalance: (json['pendingBalance'] ?? json['pendingAmount']) as num? ?? 0,
    lifetimeEarnings: json['lifetimeEarnings'] as num? ?? 0,
    totalWithdrawn: json['totalWithdrawn'] as num? ?? 0,
    pendingRewards: (json['pendingRewards'] as num?)?.toInt() ?? 0,
    completedRewards: (json['completedRewards'] as num?)?.toInt() ?? 0,
  );
}

/// One ledger row (`GET /mobile/wallet/transactions`).
///
/// This is the wallet's own record of money moving, and it is the only feed
/// that covers every earning type — `/mobile/rewards/history` only carries
/// campaign and ad rewards, so a survey payout never appears there.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.description,
    this.createdAt,
  });

  final String id;

  /// `REWARD`, `BONUS`, `WITHDRAWAL`, `ADMIN_ADJUSTMENT`.
  final String type;

  /// Signed: withdrawals arrive negative.
  final num amount;

  /// `COMPLETED`, `PENDING`, `FAILED`.
  final String status;
  final String description;
  final DateTime? createdAt;

  bool get isDebit => amount < 0;
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isFailed => status.toUpperCase() == 'FAILED';

  /// Which earning type paid this out, inferred from [type] and the
  /// description the server writes ("Completed Survey: …", "Ad Reward: …").
  /// The API sends no category field, so the text is the only signal.
  WalletActivityKind get kind {
    if (type.toUpperCase() == 'WITHDRAWAL') return WalletActivityKind.withdrawal;
    final text = description.toLowerCase();
    if (text.contains('survey')) return WalletActivityKind.survey;
    if (text.contains('quiz')) return WalletActivityKind.quiz;
    if (text.contains('campaign')) return WalletActivityKind.campaign;
    if (text.contains('ad')) return WalletActivityKind.ad;
    return WalletActivityKind.other;
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String? ?? '',
        amount: json['amount'] as num? ?? 0,
        status: json['status'] as String? ?? '',
        description: json['description'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

/// What a transaction was for — drives its icon and tint.
enum WalletActivityKind { ad, survey, quiz, campaign, withdrawal, other }

/// Earnings totals (`GET /mobile/wallet/earnings-summary`).
class EarningsSummary {
  const EarningsSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.lifetime,
  });

  final num today;
  final num thisWeek;
  final num thisMonth;
  final num lifetime;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        today: json['today'] as num? ?? 0,
        thisWeek: json['thisWeek'] as num? ?? 0,
        thisMonth: json['thisMonth'] as num? ?? 0,
        lifetime: json['lifetime'] as num? ?? 0,
      );
}

/// Earning habits (`GET /mobile/wallet/insights`).
///
/// [highestEarningDay] is free text — the API answers `"N/A"` for a user with
/// no history, so it is shown as-is rather than parsed as a date.
class WalletInsights {
  const WalletInsights({
    required this.highestEarningDay,
    required this.highestEarningAmount,
    required this.adsCompleted,
    required this.averageDailyReward,
  });

  final String highestEarningDay;
  final num highestEarningAmount;
  final int adsCompleted;
  final num averageDailyReward;

  factory WalletInsights.fromJson(Map<String, dynamic> json) => WalletInsights(
    highestEarningDay: json['highestEarningDay']?.toString() ?? 'N/A',
    highestEarningAmount: json['highestEarningAmount'] as num? ?? 0,
    adsCompleted: (json['adsCompleted'] as num?)?.toInt() ?? 0,
    averageDailyReward: json['averageDailyReward'] as num? ?? 0,
  );
}
