import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../earn_task_kind.dart';

/// A category tile on the earning tab (Figma: "Earning Opportunity",
/// 118pt wide) with how many tasks are waiting.
///
/// Grows past the design height rather than clipping when text runs long;
/// lay a row of these out inside an [IntrinsicHeight] with stretched
/// cross-axis alignment to keep them level.
class OpportunityTile extends StatelessWidget {
  const OpportunityTile({
    super.key,
    required this.kind,
    required this.count,
    required this.onTap,
  });

  final EarnTaskKind kind;

  /// Items currently on offer; loading and error states show in the badge.
  final AsyncValue<int> count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 140),
      child: SizedBox(
        width: 118,
        child: Material(
          color: kind.tint,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        kind.icon,
                        width: 24,
                        colorFilter: ColorFilter.mode(
                          kind.color,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        kind.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kind.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.35,
                          color: AppColors.slate,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  // Scales down instead of clipping when a count or a
                  // translated label runs wide.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _Status(count: count),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.count});

  final AsyncValue<int> count;

  static const _small = TextStyle(fontSize: 10, color: AppColors.slate);
  static const _alert = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.dangerText,
  );

  @override
  Widget build(BuildContext context) {
    return count.when(
      // Keep the last known state while an automatic retry is in flight
      // instead of flickering back to "Loading…".
      skipLoadingOnReload: true,
      loading: () => const Text('Loading…', style: _small),
      error: (_, _) => const Text('Unavailable', style: _alert),
      data: (pending) => pending == 0
          ? const Text('No task for today!', style: _alert)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pending:', style: _small),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pendingChip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pending',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
