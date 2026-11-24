import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Bordered, softly shadowed surface (16px radius). Optionally tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.shadow = true,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.cardRadius);
    return Container(
      margin: margin,
      decoration: AppDecor.card(color: color, shadow: shadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Tinted rounded square holding an icon.
class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon, this.color = AppColors.primary, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.tint(color, 0.1), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// "Section title ........ See all" row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.padding});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm + 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.sectionTitle)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Standard list row inside a card: leading, title, subtitle, meta, trailing.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.meta,
    this.onTap,
    this.titleStyle,
    this.subtitleColor,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? leading;
  final Widget? trailing;

  /// Extra row under the subtitle, typically badges.
  final Widget? meta;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle ?? AppText.cardTitle.copyWith(fontSize: 15)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleColor == null ? AppText.label : AppText.label.copyWith(color: subtitleColor),
                  ),
                ],
                if (meta != null) ...[const SizedBox(height: 8), meta!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Initials in a coloured circle.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 44, this.color});
  final String name;
  final double size;
  final Color? color;

  static const _palette = [AppColors.primary, AppColors.secondary, AppColors.success, AppColors.warning, AppColors.ink];

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty ? '?' : words.take(2).map((w) => w[0].toUpperCase()).join();
    final c = color ?? _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.tint(c, 0.12), shape: BoxShape.circle),
      child: Text(initials, style: AppText.labelStrong.copyWith(color: c, fontSize: size * 0.34)),
    );
  }
}

/// Label/value row for detail pages, optionally with a leading icon.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon, this.onTap, this.valueColor});
  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: AppColors.muted), const SizedBox(width: 12)],
            Expanded(
              flex: 4,
              child: Text(label, style: AppText.label),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(
                value.isEmpty ? '—' : value,
                textAlign: TextAlign.end,
                style: AppText.bodyStrong.copyWith(color: valueColor ?? AppColors.ink, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Divider-separated list of rows inside one card.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.children, this.title});
  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(title!, style: AppText.cardTitle)),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

/// Linear progress with optional percentage label.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color = AppColors.primary, this.height = 8, this.showLabel = false});
  final double value;
  final Color color;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: v,
        minHeight: height,
        color: color,
        backgroundColor: AppColors.border,
      ),
    );
    if (!showLabel) return bar;
    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: 10),
        Text('${(v * 100).round()}%', style: AppText.labelStrong),
      ],
    );
  }
}
