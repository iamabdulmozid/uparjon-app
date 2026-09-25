import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_assets.dart';
import '../utils/formatters.dart';

/// Gold wallet summary (Figma: 382x186, 16pt radius).
///
/// Shown at the top of both Home and the Wallet tab, which is why it lives
/// in the UI kit rather than in either feature.
class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    this.pending,
    this.onWithdraw,
  });

  /// Formatted balance, e.g. "16,457.15". Money is only ever formatted —
  /// the client never does arithmetic on it.
  final String balance;

  /// Earned but still held by fraud validation. Shown under the balance when
  /// it is above zero, so the user is not left wondering where a reward they
  /// just earned went. Null hides the line entirely.
  final num? pending;

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
                  if (_visible && (widget.pending ?? 0) > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.takaGrouped(widget.pending!)} pending',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray,
                      ),
                    ),
                  ],
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
