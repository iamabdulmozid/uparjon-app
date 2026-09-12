import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/ui/app_button.dart';

/// Confirmation before signing out.
///
/// Logging out is easy to trigger by accident and costs the user a full
/// re-authentication, so it asks first.
class LogoutConfirmSheet extends StatelessWidget {
  const LogoutConfirmSheet({super.key});

  /// Returns true when the user confirms.
  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.creamLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const LogoutConfirmSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Log out of Uparjon?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You'll need to log in again to keep earning.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.slate),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Log Out',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
