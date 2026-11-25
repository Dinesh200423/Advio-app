import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/modules.dart';
import '../clients/client_providers.dart';
import '../invoices/invoice_providers.dart';
import '../invoices/widgets/invoice_tile.dart';
import '../leads/lead_providers.dart';
import '../leads/widgets/lead_tile.dart';
import '../projects/project_providers.dart';
import '../reports/report_providers.dart';
import '../settings/settings_providers.dart';
import '../tasks/task_providers.dart';
import '../team/module_access.dart';
import '../team/team_providers.dart';
import '../team/team_workload.dart';
import '../tasks/widgets/task_tile.dart';
import '../automation/automation_providers.dart';
import 'activity_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    bool can(AppModule m) => ref.watch(canUseProvider(m));

    return PageScaffold(
      title: '${Fmt.greeting()}, ${ref.watch(currentMemberProvider)?.firstName ?? settings.firstName} 👋',
      subtitle: Fmt.dateLong(DateTime.now()),
      large: true,
      onRefresh: () => pullToRefresh(context),
      actions: const [_NotificationBell()],
      // Sections for modules this person does not have are left out. Their own tasks always show.
      children: [
        const _AttentionCard(),
        const SizedBox(height: 20),
        const _QuickActions(),
        const _Kpis(),
        if (can(AppModule.invoices)) const _RevenueChart(),
        const _TodaysTasks(),
        if (can(AppModule.invoices)) const _OutstandingInvoices(),
        if (can(AppModule.tasks) || can(AppModule.projects)) const _UpcomingDeadlines(),
        if (can(AppModule.leads)) const _RecentLeads(),
        const _RecentActivity(),
      ],
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return Semantics(
      label: 'Notifications, $unread unread',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(Routes.notifications),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
              if (unread > 0)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Text(
                      '$unread',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What needs you today": the dashboard's primary call to action.
class _AttentionCard extends ConsumerWidget {
  const _AttentionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Personal: what is on *your* plate, plus anything nobody owns yet.
    final me = ref.watch(currentMemberIdProvider);
    final overdueTasks = ref.watch(overdueTasksProvider).where((t) => t.assigneeId == me).length;
    final todayTasks = ref.watch(todaysTasksProvider).where((t) => t.assigneeId == me).length;
    final followUps = ref.watch(dueFollowUpsProvider).where((d) => d.lead.ownerId == me).length;
    final orphans = ref.watch(workloadProvider(null));
    final unowned = orphans.openTasks + orphans.openLeads;
    final overdueInvoices = ref.watch(outstandingInvoicesProvider).where((i) => i.displayStatus == InvoiceStatus.overdue).toList();
    final overdueAmount = ref.watch(overdueTotalProvider);

    // Reminders on this card follow the matching automation rules.
    final rules = ref.watch(automationProvider);
    bool on(AutomationKind k) => rules.any((r) => r.kind == k && r.enabled);

    final items = <({IconData icon, Color color, String text, String route})>[
      if (overdueInvoices.isNotEmpty && on(AutomationKind.invoice) && ref.watch(canUseProvider(AppModule.invoices)))
        (
          icon: Icons.receipt_long_rounded,
          color: AppColors.danger,
          text: '${overdueInvoices.length} overdue invoice${overdueInvoices.length == 1 ? '' : 's'} · ${ref.money(overdueAmount, compact: true)}',
          route: '${Routes.invoices}?status=overdue',
        ),
      if (overdueTasks > 0 && on(AutomationKind.task))
        (
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
          text: '$overdueTasks overdue task${overdueTasks == 1 ? '' : 's'}',
          route: '${Routes.tasks}?view=overdue&assignee=$me',
        ),
      if (followUps > 0 && on(AutomationKind.followUp))
        (
          icon: Icons.event_available_rounded,
          color: AppColors.warning,
          text: '$followUps lead follow-up${followUps == 1 ? '' : 's'} due',
          route: '${Routes.leads}?due=1&owner=$me',
        ),
      if (todayTasks > 0 && on(AutomationKind.task))
        (
          icon: Icons.today_rounded,
          color: AppColors.primary,
          text: '$todayTasks task${todayTasks == 1 ? '' : 's'} due today',
          route: '${Routes.tasks}?view=today&assignee=$me',
        ),
      if (unowned > 0)
        (icon: Icons.person_off_outlined, color: AppColors.muted, text: '$unowned item${unowned == 1 ? '' : 's'} with no owner', route: Routes.team),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Needs your attention', style: AppText.cardTitle),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text('You\'re all caught up. Nothing urgent today', style: AppText.body)),
                ],
              ),
            )
          else
            for (final i in items)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(i.route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 12, left: 4),
                        decoration: BoxDecoration(color: i.color, shape: BoxShape.circle),
                      ),
                      Icon(i.icon, size: 18, color: i.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(i.text, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      (module: AppModule.leads, icon: Icons.person_add_alt_1_rounded, label: 'Lead', color: AppColors.primary, route: Routes.leadNew),
      (module: AppModule.tasks, icon: Icons.task_alt_rounded, label: 'Task', color: AppColors.secondary, route: Routes.taskNew()),
      (module: AppModule.projects, icon: Icons.create_new_folder_rounded, label: 'Project', color: AppColors.success, route: Routes.projectNew()),
      (module: AppModule.invoices, icon: Icons.receipt_long_rounded, label: 'Invoice', color: AppColors.warning, route: Routes.invoiceNew()),
    ].where((a) => ref.watch(canUseProvider(a.module))).map((a) => (icon: a.icon, label: a.label, color: a.color, route: a.route)).toList();
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Quick add', style: AppText.label),
          ),
          _actionRow(context, actions),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, List<({IconData icon, String label, Color color, String route})> actions) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              onTap: () => context.push(actions[i].route),
              child: Column(
                children: [
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(color: actions[i].color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '+ ${actions[i].label}',
                    style: AppText.labelStrong.copyWith(color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Kpis extends ConsumerWidget {
  const _Kpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final projects = ref.watch(projectsProvider);
    final revenue = ref.watch(monthlyRevenueProvider);
    final pending = ref.watch(pendingTasksProvider).length;
    final overdue = ref.watch(overdueTasksProvider).length;
    final months = ref.watch(monthlyFinanceProvider(2));
    final last = months.length > 1 ? months.first.revenue : 0.0;
    final delta = last == 0 ? null : (revenue - last) / last;

    final cards = <Widget>[
      if (ref.watch(canUseProvider(AppModule.clients)))
        MetricCard(
          label: 'Total clients',
          value: '${clients.length}',
          caption: '${clients.where((c) => c.status == ClientStatus.active).length} active',
          onTap: () => context.push(Routes.clients),
        ),
      if (ref.watch(canUseProvider(AppModule.projects)))
        MetricCard(
          label: 'Active projects',
          value: '${projects.where((p) => p.status == ProjectStatus.active).length}',
          color: AppColors.secondary,
          caption: '${projects.where((p) => p.status == ProjectStatus.planned).length} planned',
          onTap: () => context.go(Routes.projects),
        ),
      if (ref.watch(canUseProvider(AppModule.invoices)))
        MetricCard(
          label: 'Monthly revenue',
          value: ref.money(revenue, compact: true),
          color: AppColors.success,
          caption: delta == null ? 'This month' : '${delta >= 0 ? '▲' : '▼'} ${(delta.abs() * 100).round()}% vs last month',
          captionColor: delta == null ? null : (delta >= 0 ? AppColors.success : AppColors.danger),
          onTap: () => context.push(Routes.reports),
        ),
      MetricCard(
        label: 'Pending tasks',
        value: '$pending',
        color: AppColors.warning,
        caption: overdue > 0 ? '$overdue overdue' : 'All on track',
        captionColor: overdue > 0 ? AppColors.danger : AppColors.success,
        onTap: () => context.push(Routes.tasks),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: MetricGrid(children: cards),
    );
  }
}

class _RevenueChart extends ConsumerWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthlyFinanceProvider(6));
    return ChartCard(
      title: 'Revenue vs expenses',
      subtitle: 'Last 6 months',
      trailing: TextButton(onPressed: () => context.push(Routes.reports), child: const Text('Reports')),
      legend: const [(label: 'Revenue', color: AppColors.primary, value: null), (label: 'Expenses', color: AppColors.secondary, value: null)],
      child: AppBarChart(
        labels: [for (final m in data) m.label],
        format: (v) => ref.money(v, compact: true),
        series: [
          ChartSeries(label: 'Revenue', color: AppColors.primary, values: [for (final m in data) m.revenue]),
          ChartSeries(label: 'Expenses', color: AppColors.secondary, values: [for (final m in data) m.expenses]),
        ],
      ),
    );
  }
}

class _TodaysTasks extends ConsumerWidget {
  const _TodaysTasks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberIdProvider);
    final tasks = ref.watch(todaysTasksProvider).where((t) => t.assigneeId == me).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Your tasks today', actionLabel: 'See all', onAction: () => context.push('${Routes.tasks}?view=today&assignee=$me')),
        if (tasks.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.celebration_rounded,
              title: 'Nothing due today',
              message: 'Enjoy the breathing room or plan ahead.',
              compact: true,
              actionLabel: 'Add task',
              onAction: () => context.push(Routes.taskNew()),
            ),
          )
        else
          for (final t in tasks.take(4)) TaskTile(task: t),
      ],
    );
  }
}

class _OutstandingInvoices extends ConsumerWidget {
  const _OutstandingInvoices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstanding = ref.watch(outstandingInvoicesProvider);
    final total = ref.watch(outstandingTotalProvider);
    final overdue = ref.watch(overdueTotalProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Outstanding invoices', actionLabel: 'View all', onAction: () => context.go(Routes.invoices)),
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          onTap: () => context.go(Routes.invoices),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total receivable', style: AppText.label),
                    const SizedBox(height: 4),
                    Text(ref.money(total), style: AppText.metric),
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overdue', style: AppText.label),
                    const SizedBox(height: 4),
                    Text(ref.money(overdue), style: AppText.metric.copyWith(color: overdue > 0 ? AppColors.danger : AppColors.ink)),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final i in outstanding.take(3)) InvoiceTile(invoice: i),
      ],
    );
  }
}

class _UpcomingDeadlines extends ConsumerWidget {
  const _UpcomingDeadlines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadlines = ref.watch(upcomingDeadlinesProvider);
    if (deadlines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Upcoming deadlines', actionLabel: 'Projects', onAction: () => context.go(Routes.projects)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < deadlines.take(4).length; i++) ...[
                _DeadlineRow(deadline: deadlines[i]),
                if (i != deadlines.take(4).length - 1) const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.deadline});
  final Deadline deadline;

  @override
  Widget build(BuildContext context) {
    final days = daysUntil(deadline.date);
    final urgent = days <= 3;
    final color = urgent ? AppColors.warning : AppColors.primary;
    return InkWell(
      onTap: () => context.push(deadline.route),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: AppColors.tint(color, 0.1), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('${deadline.date.day}', style: AppText.cardTitle.copyWith(color: color, height: 1.1)),
                  Text(
                    Fmt.month(deadline.date).toUpperCase(),
                    style: AppText.caption.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deadline.title,
                    style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(deadline.subtitle, style: AppText.caption),
                ],
              ),
            ),
            Text(
              days == 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'In $days days'),
              style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentLeads extends ConsumerWidget {
  const _RecentLeads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = [...ref.watch(leadsProvider)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Recent leads', actionLabel: 'See all', onAction: () => context.go(Routes.leads)),
        for (final l in leads.take(3)) LeadTile(lead: l),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = [...ref.watch(activityProvider)]..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Recent activity'),
        AppCard(
          child: Timeline(
            entries: [for (final a in feed.take(5)) TimelineEntry(title: a.title, subtitle: a.detail, time: Fmt.timeAgo(a.at), color: a.kind.color)],
          ),
        ),
      ],
    );
  }
}
