import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/team.dart';
import 'team_providers.dart';
import 'team_workload.dart';

/// Who is on the team and how much each person is carrying.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamProvider);
    final active = members.where((m) => m.active).toList();
    final inactive = members.where((m) => !m.active).toList();
    final me = ref.watch(currentMemberProvider);
    final nobody = ref.watch(workloadProvider(null));
    final loads = {for (final m in members) m.id: ref.watch(workloadProvider(m.id))};
    final heaviest = loads.values.fold<int>(1, (s, w) => w.total > s ? w.total : s);
    final openTasks = loads.values.fold<int>(0, (s, w) => s + w.openTasks) + nobody.openTasks;

    return PageScaffold(
      title: 'Team',
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.teamNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add member'),
      ),
      children: [
        if (me != null)
          AppCard(
            shadow: false,
            child: Row(
              children: [
                InitialsAvatar(name: me.name, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Using the app as ${me.name}', style: AppText.bodyStrong),
                      Text('Prototype: switch person to see tasks and leads from their side.', style: AppText.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => _switchUser(context, ref), child: const Text('Switch')),
              ],
            ),
          ),
        const SizedBox(height: 16),
        MetricGrid(
          children: [
            MetricCard(label: 'Team members', value: '${active.length}', caption: inactive.isEmpty ? null : '${inactive.length} inactive'),
            MetricCard(label: 'Open tasks', value: '$openTasks', caption: 'across the team'),
            MetricCard(
              label: 'Tasks with no owner',
              value: '${nobody.openTasks}',
              color: AppColors.warning,
              caption: nobody.openTasks == 0 ? 'All assigned' : 'Tap to review',
              captionColor: nobody.openTasks == 0 ? AppColors.success : AppColors.warning,
              onTap: nobody.openTasks == 0 ? null : () => context.push('${Routes.tasks}?assignee=none'),
            ),
            MetricCard(
              label: 'Leads with no owner',
              value: '${nobody.openLeads}',
              color: AppColors.warning,
              caption: nobody.openLeads == 0 ? 'All assigned' : 'Tap to review',
              captionColor: nobody.openLeads == 0 ? AppColors.success : AppColors.warning,
              onTap: nobody.openLeads == 0 ? null : () => context.push('${Routes.leads}?owner=none'),
            ),
          ],
        ),
        const SectionHeader(title: 'Members'),
        for (final m in active) _MemberCard(member: m, load: loads[m.id]!, heaviest: heaviest, isMe: m.id == me?.id),
        if (inactive.isNotEmpty) ...[
          const SectionHeader(title: 'Inactive'),
          for (final m in inactive) _MemberCard(member: m, load: loads[m.id]!, heaviest: heaviest, isMe: false),
        ],
      ],
    );
  }

  Future<void> _switchUser(BuildContext context, WidgetRef ref) async {
    final pick = await showAssigneePickerForSwitch(context, ref);
    if (pick == null || !context.mounted) return;
    ref.read(currentMemberIdProvider.notifier).switchTo(pick);
    AppSnack.info(context, 'Now using the app as ${ref.read(memberProvider(pick))?.name}');
  }
}

/// Choose which active member the app should act as.
Future<String?> showAssigneePickerForSwitch(BuildContext context, WidgetRef ref) {
  final members = ref.read(activeMembersProvider);
  final current = ref.read(currentMemberIdProvider);
  return pickOption<String>(
    context,
    title: 'Use the app as',
    options: [for (final m in members) m.id],
    selected: current,
    labelOf: (id) {
      final m = members.firstWhere((m) => m.id == id);
      return '${m.name}  ·  ${m.role.label}';
    },
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.load, required this.heaviest, required this.isMe});
  final TeamMember member;
  final Workload load;
  final int heaviest;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (load.openTasks > 0) '${load.openTasks} task${load.openTasks == 1 ? '' : 's'}${load.overdueTasks > 0 ? ' (${load.overdueTasks} overdue)' : ''}',
      if (load.openLeads > 0) '${load.openLeads} lead${load.openLeads == 1 ? '' : 's'}',
      if (load.activeProjects > 0) '${load.activeProjects} project${load.activeProjects == 1 ? '' : 's'}',
      if (load.openTickets > 0) '${load.openTickets} ticket${load.openTickets == 1 ? '' : 's'}',
      if (load.checklistItems > 0) '${load.checklistItems} checklist item${load.checklistItems == 1 ? '' : 's'}',
    ];
    return Opacity(
      opacity: member.active ? 1 : 0.6,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: () => context.push(Routes.member(member.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: member.name, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMe ? '${member.name} (you)' : member.name, style: AppText.cardTitle.copyWith(fontSize: 15)),
                      Text(member.role.label, style: AppText.label),
                    ],
                  ),
                ),
                if (!member.active) const StatusBadge(label: 'Inactive', color: AppColors.muted, dot: false),
              ],
            ),
            const SizedBox(height: 14),
            AppProgressBar(value: load.total / heaviest, height: 6, color: load.overdueTasks > 0 ? AppColors.warning : AppColors.primary),
            const SizedBox(height: 8),
            Text(parts.isEmpty ? 'Nothing assigned' : parts.join('  ·  '), style: AppText.caption),
          ],
        ),
      ),
    );
  }
}
