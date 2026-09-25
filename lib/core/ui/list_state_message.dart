import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Empty-state / error text for a list, with an optional Retry.
///
/// Lives in the UI kit because the earning lists, Home's Recent Activity
/// and the wallet ledger all need the same treatment.
class ListStateMessage extends StatelessWidget {
  const ListStateMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.slate,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.amber),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
