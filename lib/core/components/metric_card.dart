import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';

/// KPI tile: icon, big value, label and an optional caption line.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.primary,
    this.caption,
    this.captionColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final String? caption;
  final Color? captionColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Row(
              children: [
                IconChip(icon: icon!, color: color, size: 36),
                const Spacer(),
                if (onTap != null) const Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 14),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.metric, maxLines: 1),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: AppText.caption.copyWith(color: captionColor ?? AppColors.muted, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Responsive grid for [MetricCard]s: 2 columns on phones, 4 on wide screens.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children, this.spacing = 12});
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 4 : 2;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      },
    );
  }
}
