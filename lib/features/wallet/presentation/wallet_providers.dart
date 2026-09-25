import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';

/// Balance summary (`GET /mobile/wallet/overview`).
///
/// Home's balance card and the Wallet tab both watch this, so the two agree
/// and the endpoint is hit once for both.
final walletOverviewProvider = FutureProvider.autoDispose<WalletOverview>(
  (ref) => ref.watch(walletRepositoryProvider).overview(),
);

/// First page of the ledger (`GET /mobile/wallet/transactions`) — the Wallet
/// tab's history list and Home's Recent Activity.
final walletTransactionsProvider =
    FutureProvider.autoDispose<Paged<WalletTransaction>>(
      (ref) => ref.watch(walletRepositoryProvider).transactions(),
    );

/// How many ledger rows the Wallet tab has asked for; "Load more" raises it.
final walletHistorySizeProvider = NotifierProvider<WalletHistorySize, int>(
  WalletHistorySize.new,
);

class WalletHistorySize extends Notifier<int> {
  static const int pageSize = 20;

  @override
  int build() => pageSize;

  void loadMore() => state = state + pageSize;
}

/// The Wallet tab's history list.
///
/// Same endpoint as [walletTransactionsProvider], but sized by
/// [walletHistorySizeProvider] — refetching the whole range on "Load more"
/// keeps the list a plain function of that size, with no accumulated state to
/// fall out of step with the server.
final walletHistoryProvider =
    FutureProvider.autoDispose<Paged<WalletTransaction>>(
      (ref) => ref
          .watch(walletRepositoryProvider)
          .transactions(size: ref.watch(walletHistorySizeProvider)),
    );

/// Today / week / month / lifetime earnings.
final walletEarningsProvider = FutureProvider.autoDispose<EarningsSummary>(
  (ref) => ref.watch(walletRepositoryProvider).earningsSummary(),
);

/// Best day, ads completed, daily average.
final walletInsightsProvider = FutureProvider.autoDispose<WalletInsights>(
  (ref) => ref.watch(walletRepositoryProvider).insights(),
);

/// Refreshes every wallet figure — call after a reward-producing action so
/// the balance and the ledger catch up with what the user just earned.
void invalidateWallet(WidgetRef ref) {
  ref.invalidate(walletOverviewProvider);
  ref.invalidate(walletTransactionsProvider);
  ref.invalidate(walletHistoryProvider);
  ref.invalidate(walletEarningsProvider);
  ref.invalidate(walletInsightsProvider);
}
