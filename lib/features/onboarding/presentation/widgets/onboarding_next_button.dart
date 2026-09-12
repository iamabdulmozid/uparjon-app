import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Gradient "next" button ringed by a circular progress track.
///
/// The ring fills as the user advances and is complete on the last slide.
/// Geometry mirrors the Figma design (button ⌀68, ring ⌀88.6, stroke 2.8,
/// arc starting at the upper-left and sweeping clockwise).
class OnboardingNextButton extends StatelessWidget {
  const OnboardingNextButton({
    super.key,
    required this.progress,
    required this.onPressed,
    this.semanticLabel = 'Next',
  });

  /// Completion of the carousel, 0..1.
  final double progress;
  final VoidCallback onPressed;
  final String semanticLabel;

  static const double _buttonSize = 68;
  static const double _ringSize = 92;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: _ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Track + progress arc.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, _) => CustomPaint(
                size: const Size.square(_ringSize),
                painter: _ProgressRingPainter(value),
              ),
            ),
            // The button itself.
            DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.amberGradient,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: const SizedBox.square(
                    dimension: _buttonSize,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter(this.progress);

  final double progress;

  /// Where the arc begins — upper-left, per the design.
  static const double _startAngle = 210 * math.pi / 180;
  static const double _strokeWidth = 2.8;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - _strokeWidth) / 2,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..color = AppColors.divider;
    canvas.drawCircle(rect.center, rect.width / 2, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.amber;
    canvas.drawArc(rect, _startAngle, progress * 2 * math.pi, false, arc);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
