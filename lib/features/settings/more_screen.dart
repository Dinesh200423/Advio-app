import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../checklists/checklist_providers.dart';
import '../settings/settings_providers.dart';
import '../support/support_providers.dart';
import '../tasks/task_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final openTickets = ref.watch(ticketsProvider).where((t) => t.status.isActive).length;
    final pendingTasks = ref.watch(pendingTasksProvider).length;
    final waitingOnClient = ref.watch(checklistsProvider).fold<int>(0, (s, c) => s + c.waitingCount);

    final items = <({IconData icon, Color color, String label, String route, String? badge})>[
      (icon: Icons.business_rounded, color: AppColors.primary, label: 'Clients', route: Routes.clients, badge: null),
      (icon: Icons.groups_rounded, color: AppColors.primary, label: 'Team', route: Routes.team, badge: null),
      (icon: Icons.task_alt_rounded, color: AppColors.secondary, label: 'Tasks', route: Routes.tasks, badge: pendingTasks > 0 ? '$pendingTasks' : null),
      (icon: Icons.fact_check_rounded, color: AppColors.primary, label: 'Delivery checklists', route: Routes.checklists, badge: waitingOnClient > 0 ? '$waitingOnClient' : null),
      (icon: Icons.request_quote_rounded, color: AppColors.warning, label: 'Quotations', route: Routes.quotations, badge: null),
      (icon: Icons.shopping_bag_rounded, color: AppColors.danger, label: 'Expenses', route: Routes.expenses, badge: null),
      (icon: Icons.support_agent_rounded, color: AppColors.success, label: 'Support & Maintenance', route: Routes.support, badge: openTickets > 0 ? '$openTickets' : null),
      (icon: Icons.bolt_rounded, color: AppColors.secondary, label: 'Automation', route: Routes.automation, badge: null),
      (icon: Icons.insights_rounded, color: AppColors.primary, label: 'Reports', route: Routes.reports, badge: null),
      (icon: Icons.settings_rounded, color: AppColors.muted, label: 'Settings', route: Routes.settings, badge: null),
    ];

    return PageScaffold(
      title: 'More',
      large: true,
      children: [
        AppCard(
          onTap: () => context.push(Routes.settingsProfile),
          child: Row(
            children: [
              InitialsAvatar(name: settings.name, size: 56, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settings.name, style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text(settings.businessName, style: AppText.label),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 640 ? 3 : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final i in items)
                  SizedBox(
                    width: w,
                    child: AppCard(
                      onTap: () => context.push(i.route),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 18, height: 3, decoration: BoxDecoration(color: i.color, borderRadius: BorderRadius.circular(3))),
                              const Spacer(),
                              if (i.badge != null) StatusBadge(label: i.badge!, color: i.color, dot: false),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(i.label, style: AppText.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
