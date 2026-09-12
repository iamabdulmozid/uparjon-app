import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';

/// The three product pillars. Freelance and e-Commerce ship in later phases,
/// so they are shown but marked [enabled] `false` until then.
class ModuleTiles extends StatelessWidget {
  const ModuleTiles({super.key, required this.onTap});

  final void Function(String module) onTap;

  @override
  Widget build(BuildContext context) {
    const modules = [
      _Module('Uparjon', AppAssets.iconTrophy, Color(0xFFFDF7E9), true),
      _Module('Freelance', AppAssets.iconSuitcase, Color(0xFFEFF6F2), false),
      _Module('e-Commerce', AppAssets.iconCart, Color(0xFFF7F3FC), false),
    ];

    return Row(
      children: [
        for (final m in modules) ...[
          if (m != modules.first) const SizedBox(width: 16),
          Expanded(
            child: _Tile(module: m, onTap: () => onTap(m.label)),
          ),
        ],
      ],
    );
  }
}

class _Module {
  const _Module(this.label, this.icon, this.background, this.enabled);

  final String label;
  final String icon;
  final Color background;
  final bool enabled;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.module, required this.onTap});

  final _Module module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: module.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 116,
          child: Opacity(
            opacity: module.enabled ? 1 : 0.55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  module.icon,
                  width: 32,
                  colorFilter: const ColorFilter.mode(
                    AppColors.charcoal,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  module.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
