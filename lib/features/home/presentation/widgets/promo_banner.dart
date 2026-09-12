import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';

/// Dark teal advertiser promo carousel (Figma: 382x130, 12pt radius).
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final PageController _controller = PageController();
  int _index = 0;

  // TODO(api): promos come from a campaigns endpoint.
  static const _slides = [
    ('BDT 1000', "Don't just post your Ad."),
    ('BDT 5000', 'Reach 10x more people.'),
    ('BDT 10000', 'Run a full campaign.'),
    ('BDT 25000', 'Go nationwide.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 130,
        color: const Color(0xFF00424A),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 16,
              child: Image.asset(AppAssets.promoIllustration, width: 143),
            ),
            PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _Slide(
                amount: _slides[i].$1,
                tagline: _slides[i].$2,
                onTap: widget.onTap,
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Row(
                children: [
                  for (var i = 0; i < _slides.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 9,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? const Color(0xFFFAC123)
                            : const Color(0xFF15616B),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.amount, required this.tagline, this.onTap});

  final String amount;
  final String tagline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 150, 16),
        // Scales down instead of overflowing when the copy runs long
        // (longer Bangla strings, large system font scale).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Advertise just for',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              Text.rich(
                const TextSpan(
                  text: 'Get ',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                  children: [
                    TextSpan(
                      text: 'real engagement',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFAC123),
                      ),
                    ),
                    TextSpan(text: ' from the right person.'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
