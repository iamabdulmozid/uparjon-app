import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// White stat card at the top of the earning screens (Figma: 182x95).
///
/// Sized by its content with a design-height floor, so a larger system font
/// grows the card instead of overflowing it. Put a row of these inside an
/// [IntrinsicHeight] with stretched cross-axis alignment to keep them level.
class EarnStatCard extends StatelessWidget {
  const EarnStatCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(child: child),
    );
  }
}

/// A figure over its label — "৳ 60 / Today's Earning", "04 / Remaining Ad".
class EarnValueStat extends StatelessWidget {
  const EarnValueStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.slate),
        ),
      ],
    );
  }
}

/// A progress ring with a figure inside — "45% Task Completed",
/// "5 Remaining Task".
class EarnRingStat extends StatelessWidget {
  const EarnRingStat({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
  });

  /// 0..1 fill of the ring.
  final double progress;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: CustomPaint(
            painter: _RingPainter(progress.clamp(0.0, 1.0)),
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.slate),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);

    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = AppColors.orange
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
