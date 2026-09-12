import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';

/// Gold wallet summary at the top of Home (Figma: 382x186, 16pt radius).
class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key, required this.balance, this.onWithdraw});

  /// Formatted balance, e.g. "16,457.15". Money is always formatted by the
  /// server — the client never does arithmetic on it.
  final String balance;
  final VoidCallback? onWithdraw;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 186,
        color: const Color(0xFFF9C33D),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppAssets.balanceCardTexture,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: SvgPicture.asset(AppAssets.moneyBag, height: 118),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _visible = !_visible),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _visible ? 'Hide balance' : 'Show balance',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _visible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: AppColors.charcoal,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Total Balance',
                    style: TextStyle(fontSize: 14, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _visible ? '৳ ${widget.balance}' : '৳ ••••••',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _WithdrawButton(onPressed: widget.onWithdraw),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawButton extends StatelessWidget {
  const _WithdrawButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEDB82),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.iconUpload,
                width: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.charcoal,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Withdraw',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
