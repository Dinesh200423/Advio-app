import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../leads/lead_providers.dart';
import '../leads/widgets/lead_tile.dart';
import '../projects/project_providers.dart';
import '../projects/widgets/project_tile.dart';
import '../support/support_providers.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_tile.dart';
import 'team_providers.dart';
import 'team_workload.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider(id));
    if (member == null) return const MissingRecord(what: 'Team member', fallback: Routes.team);
    final load = ref.watch(workloadProvider(id));
    final notifier = ref.read(teamProvider.notifier);

    final tasks = ref.watch(tasksProvider).where((t) => t.assigneeId == id).toList()
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });
    final leads = ref.watch(leadsProvider).where((l) => l.ownerId == id && l.status.isOpen).toList();
    final projects = ref.watch(projectsProvider).where((p) => p.ownerId == id).toList();
    final tickets = ref.watch(ticketsProvider).where((t) => t.assigneeId == id && t.status.isActive).toList();

    return PageScaffold(
      title: member.name,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) async {
            if (v == 'edit') {
              context.push(Routes.memberEdit(id));
            } else if (v == 'toggle') {
              if (member.active && load.total > 0) {
                final ok = await confirmDialog(
                  context,
                  title: 'Deactivate ${member.name}?',
                  message: 'They have ${load.total} open items. Those stay assigned to them until you reassign them, but nothing new can be given to ${member.name}.',
                  confirmLabel: 'Deactivate',
                  destructive: true,
                );
                if (!ok) return;
              }
              notifier.setActive(id, !member.active);
              if (context.mounted) AppSnack.info(context, member.active ? '${member.name} deactivated' : '${member.name} is active again');
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'toggle', child: Text(member.active ? 'Deactivate' : 'Reactivate')),
          ],
        ),
      ],
      children: [
        AppCard(
          child: Row(
            children: [
              InitialsAvatar(name: member.name, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: AppText.sectionTitle),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      StatusBadge(label: member.role.label, color: AppColors.primary, dot: false),
                      if (!member.active) const StatusBadge(label: 'Inactive', color: AppColors.muted, dot: false),
                    ]),
                    const SizedBox(height: 8),
                    Text('With ADVIO since ${Fmt.date(member.joinedAt)}', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (member.email.isNotEmpty || member.phone.isNotEmpty) ...[
          const SizedBox(height: 12),
          InfoCard(children: [
            if (member.email.isNotEmpty) InfoRow(label: 'Email', value: member.email),
            if (member.phone.isNotEmpty) InfoRow(label: 'Phone', value: member.phone),
          ]),
        ],
        const SizedBox(height: 16),
        MetricGrid(
          children: [
            MetricCard(label: 'Open tasks', value: '${load.openTasks}', caption: load.overdueTasks > 0 ? '${load.overdueTasks} overdue' : 'None overdue', captionColor: load.overdueTasks > 0 ? AppColors.danger : AppColors.success),
            MetricCard(label: 'Leads owned', value: '${load.openLeads}'),
            MetricCard(label: 'Projects', value: '${load.activeProjects}', caption: 'active or planned'),
            MetricCard(label: 'Checklist items', value: '${load.checklistItems}', caption: '${load.openTickets} open tickets'),
          ],
        ),
        const SizedBox(height: 20),
        TabbedSection(
          tabs: {
            'Tasks': (_) => _List(empty: 'No tasks assigned', children: [for (final t in tasks) TaskTile(task: t)]),
            'Leads': (_) => _List(empty: 'No open leads', children: [for (final l in leads) LeadTile(lead: l)]),
            'Projects': (_) => _List(empty: 'Not running any projects', children: [for (final p in projects) ProjectTile(project: p)]),
            'Tickets': (_) => _List(
                  empty: 'No open tickets',
                  children: [
                    for (final t in tickets)
                      AppListTile(onTap: () => context.push(Routes.ticket(t.id)), title: t.title, subtitle: t.number, trailing: t.priority.badge),
                  ],
                ),
          },
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.empty, required this.children});
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return EmptyState(icon: Icons.inbox_outlined, title: empty, compact: true);
    return Column(children: children);
  }
}
