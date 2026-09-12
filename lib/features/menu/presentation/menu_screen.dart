import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/snackbar_service.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/logout_confirm_sheet.dart';
import 'widgets/menu_row.dart';

/// Menu tab (Figma: "Menu") — account shortcuts and the logout action.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  /// Rows above the divider. Destinations land as their features are built.
  static const _rows = [
    (label: 'Profile', icon: AppAssets.menuProfile),
    (label: 'Settings', icon: AppAssets.menuSettings),
    (label: 'Language', icon: AppAssets.menuLanguage),
    (label: 'Default Withdraw Method', icon: AppAssets.menuWithdrawMethod),
    (label: 'Watch Tutorial', icon: AppAssets.menuTutorial),
    (label: 'About Us', icon: AppAssets.menuAbout),
    (label: 'Terms & Condition', icon: AppAssets.menuTerms),
    (label: 'Help & Support', icon: AppAssets.menuSupport),
    (label: 'FAQ', icon: AppAssets.menuFaq),
  ];

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await LogoutConfirmSheet.show(context);
    if (confirmed != true || !context.mounted) return;

    // Revokes the session server-side and clears the stored tokens; the
    // local session is dropped either way.
    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) return;

    context.goNamed(Routes.login);
    SnackbarService.showSuccess('You have been logged out.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Menu',
          style: TextStyle(fontSize: 18, color: AppColors.ink),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final row in _rows)
              MenuRow(
                label: row.label,
                icon: row.icon,
                // TODO(menu): route to each destination as it is built.
                onTap: () =>
                    SnackbarService.showInfo('${row.label} is coming soon.'),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Divider(color: AppColors.border, height: 1),
            ),
            MenuRow(
              label: 'Log Out',
              icon: AppAssets.menuLogout,
              destructive: true,
              onTap: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
