import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/ui/placeholder_page.dart';

/// Wallet — balance, earnings history and withdrawals.
///
/// TODO(wallet): build the balance summary, transaction history and the
/// bKash / Nagad / Rocket withdrawal flow (Figma: "Wallet").
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Wallet',
      icon: AppAssets.iconWallet,
      message:
          'Your balance, earnings history and withdrawals\n'
          'will live here.',
    );
  }
}
