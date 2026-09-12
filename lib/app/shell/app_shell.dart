import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../features/earn/presentation/earn_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../theme/app_colors.dart';
import 'shell_tab.dart';

/// Bottom-navigation shell (Figma: "Navbar").
///
/// Tabs are kept alive in an [IndexedStack] so scroll position and state
/// survive switching. The selected tab lives in [shellTabProvider] so other
/// screens can switch tabs too.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Tabs the user has actually opened. An unvisited tab renders as a blank
  /// placeholder so its feeds do not fetch until it is needed — the earning
  /// tab alone would otherwise hit several endpoints on every app open.
  final Set<int> _visited = {ShellTab.home};

  static const _tabs = [
    (label: 'Home', icon: AppAssets.iconHome),
    (label: 'Uparjon', icon: AppAssets.iconTrophy),
    (label: 'Wallet', icon: AppAssets.iconWallet),
    (label: 'Menu', icon: AppAssets.iconMenu),
  ];

  Widget _pageFor(int index) => switch (index) {
    ShellTab.home => const HomeScreen(),
    ShellTab.earn => const EarnScreen(),
    ShellTab.wallet => const WalletScreen(),
    _ => const MenuScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);
    _visited.add(index);

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            _visited.contains(i) ? _pageFor(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0EEEC))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      label: _tabs[i].label,
                      icon: _tabs[i].icon,
                      selected: i == index,
                      onTap: () =>
                          ref.read(shellTabProvider.notifier).select(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.amber : AppColors.divider;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icon,
            width: 24,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.charcoal : AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}
