import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';

class TimelineEntry {
  const TimelineEntry({
    required this.title,
    required this.time,
    this.subtitle,
    this.color = AppColors.primary,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String time;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
}

/// Vertical timeline used for activity history, follow-ups, payments and notes.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.entries});
  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) _Row(entry: entries[i], isLast: i == entries.length - 1),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.isLast});
  final TimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 16,
              child: Column(
                children: [
                  const SizedBox(height: 7),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
                  ),
                  if (!isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.only(top: 4), color: AppColors.border)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                          if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(entry.subtitle!, style: AppText.body.copyWith(color: AppColors.muted, fontSize: 13)),
                          ],
                          const SizedBox(height: 4),
                          Text(entry.time, style: AppText.caption),
                        ],
                      ),
                    ),
                    if (entry.trailing != null) ...[const SizedBox(width: 8), entry.trailing!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
