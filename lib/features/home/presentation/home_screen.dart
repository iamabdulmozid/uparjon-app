import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/snackbar_service.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/activity_tile.dart';
import 'widgets/balance_card.dart';
import 'widgets/module_tiles.dart';
import 'widgets/promo_banner.dart';

/// Home dashboard (Figma: "Main Home").
///
/// TODO(api): balance and recent activity are placeholders until the
/// wallet/activity endpoints exist.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final name = user?.shortName ?? 'there';

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Header(name: name),
            const SizedBox(height: 20),
            BalanceCard(
              balance: '16,457.15',
              onWithdraw: () =>
                  SnackbarService.showInfo('Withdrawal is coming soon.'),
            ),
            const SizedBox(height: 24),
            ModuleTiles(
              onTap: (module) => SnackbarService.showInfo(
                module == 'Uparjon'
                    ? 'Earning tasks are coming next.'
                    : '$module arrives in a later release.',
              ),
            ),
            const SizedBox(height: 24),
            PromoBanner(
              onTap: () =>
                  SnackbarService.showInfo('Advertiser signup is coming soon.'),
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
            const ActivityTile(
              title: 'Video Ad',
              subtitle: 'Watch video ad and earn money',
              amount: '+ ৳15.00',
              timestamp: '11 Jul 26 | 10:10 am',
              icon: AppAssets.iconVideo,
              background: Color(0xFFFDF7E9),
            ),
            const SizedBox(height: 8),
            const ActivityTile(
              title: 'Survey',
              subtitle: 'Complete survey and earn money',
              amount: '+ ৳10.00',
              timestamp: '11 Jul 26 | 10:10 am',
              icon: AppAssets.iconClipboard,
              background: Color(0xFFF7F3FC),
            ),
            const SizedBox(height: 8),
            const ActivityTile(
              title: 'Video Ad',
              subtitle: 'Watch video ad and earn money',
              amount: '+ ৳15.00',
              timestamp: '10 Jul 26 | 09:02 am',
              icon: AppAssets.iconVideo,
              background: Color(0xFFF0F4FC),
            ),
          ],
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
