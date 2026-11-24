import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/automation_rule.dart';
import '../../data/models/enums.dart';
import '../dashboard/activity_providers.dart';
import 'automation_providers.dart';

/// Visual list of automation rules with on/off switches. Nothing here talks to a
/// real workflow engine yet: the first two rules do act on the in-memory data.
class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(automationProvider);
    final enabled = rules.where((r) => r.enabled).length;
    final runs = rules.fold<int>(0, (s, r) => s + r.runs);
    final recent = ref.watch(activityProvider).where((a) => a.kind == ActivityKind.automation).take(4).toList()
      ..sort((a, b) => b.at.compareTo(a.at));

    return PageScaffold(
      title: 'Automation',
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(child: _Stat(label: 'Active rules', value: '$enabled of ${rules.length}')),
              Container(width: 1, height: 40, color: AppColors.border),
              const SizedBox(width: 16),
              Expanded(child: _Stat(label: 'Total runs', value: '$runs')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Rules react to what happens in the app. Turn the reminder rules off and the matching items disappear from your dashboard. This is a preview: no external workflow is connected.',
          style: AppText.caption.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
        for (final r in rules) _RuleCard(rule: r),
        if (recent.isNotEmpty) ...[
          const SectionHeader(title: 'Recent automation activity'),
          AppCard(
            child: Timeline(
              entries: [
                for (final a in recent)
                  TimelineEntry(title: a.title, subtitle: a.detail, time: Fmt.timeAgo(a.at), color: AppColors.secondary),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label, style: AppText.label), const SizedBox(height: 4), Text(value, style: AppText.metric)],
      );
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule});
  final AutomationRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = rule.enabled;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(rule.name, style: AppText.cardTitle.copyWith(fontSize: 15, color: on ? AppColors.ink : AppColors.muted))),
              Switch(
                value: on,
                onChanged: (v) {
                  ref.read(automationProvider.notifier).toggle(rule.id, v);
                  AppSnack.info(context, '${rule.name} ${v ? 'turned on' : 'turned off'}');
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Step(tag: 'WHEN', text: rule.trigger, color: on ? AppColors.primary : AppColors.muted),
          const SizedBox(height: 8),
          _Step(tag: 'THEN', text: rule.action, color: on ? AppColors.secondary : AppColors.muted),
          const SizedBox(height: 12),
          Text(
            rule.lastRun == null ? 'Never run' : '${rule.runs} runs  ·  last ${Fmt.timeAgo(rule.lastRun!)}',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.tag, required this.text, required this.color});
  final String tag;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.tint(color, 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(tag, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.6)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13.5))),
      ],
    );
  }
}
