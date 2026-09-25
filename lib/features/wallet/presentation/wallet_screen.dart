import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/error/failure.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/ui/balance_card.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/utils/formatters.dart';
import '../data/wallet_models.dart';
import 'wallet_providers.dart';
import 'widgets/transaction_tile.dart';

/// Wallet — balance, earnings breakdown and the transaction ledger.
///
/// Every block reads its own provider, so a single failing endpoint degrades
/// one card instead of blanking the tab.
///
/// TODO(withdraw): the withdrawal flow needs `GET /withdrawal-methods` to
/// return something — staging answers with an empty list today, so there is
/// no channel to pay out to and the button stays a notice.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(walletOverviewProvider);
    final earnings = ref.watch(walletEarningsProvider);
    final history = ref.watch(walletHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Wallet',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () async => invalidateWallet(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            BalanceCard(
              balance: overview.value == null
                  ? '—'
                  : Formatters.grouped(overview.value!.availableBalance),
              pending: overview.value?.pendingBalance,
              onWithdraw: () =>
                  SnackbarService.showInfo('Withdrawal is coming soon.'),
            ),
            if (overview.hasError) ...[
              const SizedBox(height: 8),
              ListStateMessage(
                message: _messageOf(
                  overview.error!,
                  'Could not load your balance.',
                ),
                onRetry: () => ref.invalidate(walletOverviewProvider),
              ),
            ],
            const SizedBox(height: 20),
            _StatRow(overview: overview.value),
            const SizedBox(height: 24),
            const _SectionTitle('Earnings'),
            const SizedBox(height: 12),
            _EarningsRow(summary: earnings.value),
            const SizedBox(height: 28),
            const _SectionTitle('Transaction History'),
            const SizedBox(height: 12),
            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                ),
              ),
              error: (error, _) => ListStateMessage(
                message: _messageOf(error, 'Could not load your transactions.'),
                onRetry: () => ref.invalidate(walletHistoryProvider),
              ),
              data: (page) => page.items.isEmpty
                  ? const ListStateMessage(
                      message:
                          'No transactions yet. Complete a task on the '
                          'Uparjon tab and your first reward lands here.',
                    )
                  : Column(
                      children: [
                        for (final (i, item) in page.items.indexed) ...[
                          if (i > 0) const SizedBox(height: 8),
                          TransactionTile(transaction: item),
                        ],
                        if (page.hasMore) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref
                                .read(walletHistorySizeProvider.notifier)
                                .loadMore(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.amber,
                            ),
                            child: const Text(
                              'Load more',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _messageOf(Object error, String fallback) =>
      error is Failure ? error.message : fallback;
}

/// Lifetime earned against total withdrawn — what the balance is made of.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.overview});

  final WalletOverview? overview;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _WalletStatCard(
              label: 'Lifetime Earned',
              value: overview == null
                  ? '—'
                  : Formatters.takaGrouped(overview!.lifetimeEarnings),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _WalletStatCard(
              label: 'Total Withdrawn',
              value: overview == null
                  ? '—'
                  : Formatters.takaGrouped(overview!.totalWithdrawn),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.summary});

  final EarningsSummary? summary;

  @override
  Widget build(BuildContext context) {
    String at(num Function(EarningsSummary) pick) =>
        summary == null ? '—' : Formatters.takaCompact(pick(summary!));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _WalletStatCard(label: 'Today', value: at((s) => s.today)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _WalletStatCard(
              label: 'This Week',
              value: at((s) => s.thisWeek),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _WalletStatCard(
              label: 'This Month',
              value: at((s) => s.thisMonth),
            ),
          ),
        ],
      ),
    );
  }
}

/// White figure-over-label card, sized by its content with a design-height
/// floor so a larger system font grows it instead of overflowing it.
class _WalletStatCard extends StatelessWidget {
  const _WalletStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}
