import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';

/// A task row in the earning lists (Figma: "Uparjon - Ad list").
///
/// Shows what the task is, roughly how long it takes, and what it pays.
class EarnTaskCard extends StatelessWidget {
  const EarnTaskCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.reward,
    this.iconColor = AppColors.blue,
    this.iconBackground = AppColors.blueTint,
  });

  final String title;
  final String icon;
  final VoidCallback onTap;
  final String? subtitle;

  /// Pre-formatted payout, e.g. "+ ৳10.00".
  final String? reward;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconBadge(
                      icon: icon,
                      color: iconColor,
                      background: iconBackground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null || reward != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.hint,
                          ),
                        ),
                      ),
                      if (reward != null)
                        Text(
                          reward!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenDeep,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A finished task (Figma: card tinted in the category colour with a check
/// badge and the earned amount). [pending] rewards are still in fraud
/// validation.
class CompletedTaskCard extends StatelessWidget {
  const CompletedTaskCard({
    super.key,
    required this.title,
    required this.message,
    this.pending = false,
    this.icon = AppAssets.iconClipboard,
    this.color = AppColors.blue,
    this.tint = AppColors.blueTint,
  });

  final String title;
  final String message;
  final bool pending;
  final String icon;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: icon, color: color, background: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: pending ? AppColors.amber : color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pending ? Icons.hourglass_bottom_rounded : Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: pending ? AppColors.slate : AppColors.greenDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.background,
  });

  final String icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(
        child: SvgPicture.asset(
          icon,
          width: 22,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}
