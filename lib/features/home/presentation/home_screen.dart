import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/error/failure.dart';
import '../../../core/ui/balance_card.dart';
import '../../../core/ui/list_state_message.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../app/shell/shell_tab.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../wallet/presentation/wallet_providers.dart';
import '../../wallet/presentation/widgets/transaction_tile.dart';
import 'widgets/module_tiles.dart';
import 'widgets/promo_banner.dart';

/// Home dashboard (Figma: "Main Home").
///
/// Home aggregates other modules rather than owning data of its own, so it
/// reads the wallet through that feature's providers — the balance here and
/// the one on the Wallet tab come from the same fetch and cannot disagree.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// How many ledger rows Recent Activity shows before the Wallet tab takes
  /// over.
  static const _activityCount = 3;

  static const _activityTints = [
    AppColors.amberTint,
    AppColors.purpleTint,
    AppColors.lavenderTint,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final name = user?.shortName ?? 'there';
    final overview = ref.watch(walletOverviewProvider);
    final transactions = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.amber,
          onRefresh: () async => invalidateWallet(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(name: name),
              const SizedBox(height: 20),
              BalanceCard(
                // Em dash until the first fetch lands, so the card never
                // shows a number that is not the user's.
                balance: overview.value == null
                    ? '—'
                    : Formatters.grouped(overview.value!.availableBalance),
                pending: overview.value?.pendingBalance,
                onWithdraw: () =>
                    SnackbarService.showInfo('Withdrawal is coming soon.'),
              ),
              const SizedBox(height: 24),
              ModuleTiles(
                onTap: (module) {
                  if (module == 'Uparjon') {
                    ref.read(shellTabProvider.notifier).select(ShellTab.earn);
                    return;
                  }
                  SnackbarService.showInfo(
                    '$module arrives in a later release.',
                  );
                },
              ),
              const SizedBox(height: 24),
              PromoBanner(
                onTap: () => SnackbarService.showInfo(
                  'Advertiser signup is coming soon.',
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 16),
              transactions.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  ),
                ),
                error: (error, _) => ListStateMessage(
                  message: error is Failure
                      ? error.message
                      : 'Could not load your activity.',
                  onRetry: () => ref.invalidate(walletTransactionsProvider),
                ),
                data: (page) {
                  final rows = page.items.take(_activityCount).toList();
                  if (rows.isEmpty) {
                    return const ListStateMessage(
                      message:
                          'Nothing here yet. Earn your first reward and it '
                          'will show up.',
                    );
                  }
                  return Column(
                    children: [
                      for (final (i, item) in rows.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        TransactionTile(
                          transaction: item,
                          tint: _activityTints[i % _activityTints.length],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEDEBEA)),
          ),
          child: const Icon(
            Icons.person_outline,
            size: 22,
            color: AppColors.slate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Hi, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _NotificationBell(
          onTap: () => SnackbarService.showInfo('No new notifications.'),
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDF7E9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: 22,
                color: AppColors.charcoal,
              ),
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
