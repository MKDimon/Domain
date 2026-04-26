import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum TierBadgeSize { sm, md }

class TierBadge extends StatelessWidget {
  final String tier;
  final TierBadgeSize size;

  const TierBadge({
    super.key,
    required this.tier,
    this.size = TierBadgeSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final isPro = tier == 'pro';

    final double fontSize;
    final EdgeInsets padding;
    switch (size) {
      case TierBadgeSize.sm:
        fontSize = 10;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2);
      case TierBadgeSize.md:
        fontSize = 11;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 3);
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isPro ? c.accent : c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: isPro ? null : Border.all(color: c.border, width: 1),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: isPro ? c.textOnAccent : c.textSecondary,
          letterSpacing: 0.04 * fontSize,
          height: 1,
        ),
      ),
    );
  }
}
