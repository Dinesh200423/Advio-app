import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../router/routes.dart';
import '../theme/app_text.dart';

/// Persistent frame for every main screen: bottom navigation + global quick-action button.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (label: 'Home', icon: Icons.home_outlined, selected: Icons.home_rounded, route: Routes.home),
    (label: 'Leads', icon: Icons.person_search_outlined, selected: Icons.person_search_rounded, route: Routes.leads),
    (label: 'Projects', icon: Icons.folder_open_outlined, selected: Icons.folder_rounded, route: Routes.projects),
    (label: 'Finance', icon: Icons.account_balance_wallet_outlined, selected: Icons.account_balance_wallet_rounded, route: Routes.finance),
    (label: 'More', icon: Icons.grid_view_outlined, selected: Icons.grid_view_rounded, route: Routes.more),
  ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = Routes.tabIndexFor(path);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showFab = Routes.tabRoots.contains(path) && !keyboardOpen;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      floatingActionButton: AnimatedScale(
        scale: showFab ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          heroTag: 'quick-actions',
          tooltip: 'Quick actions',
          onPressed: showFab ? () => showQuickActions(context) : null,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) {
                  if (i == index && path == _tabs[i].route) return;
                  context.go(_tabs[i].route);
                },
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selected, color: AppColors.primary),
                      label: t.label,
                    ),
                ],
              ),
            ),
    );
  }
}

/// Bottom sheet with the four global create actions.
Future<void> showQuickActions(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Quick actions',
    builder: (ctx) {
      final actions = [
        (icon: Icons.person_add_alt_1_rounded, label: 'Add Lead', hint: 'Capture a new prospect', color: AppColors.primary, route: Routes.leadNew),
        (icon: Icons.task_alt_rounded, label: 'Add Task', hint: 'Plan something to do', color: AppColors.secondary, route: Routes.taskNew()),
        (icon: Icons.create_new_folder_rounded, label: 'Create Project', hint: 'Start a client project', color: AppColors.success, route: Routes.projectNew()),
        (icon: Icons.receipt_long_rounded, label: 'Create Invoice', hint: 'Bill a client', color: AppColors.warning, route: Routes.invoiceNew()),
      ];
      return Column(
        children: [
          for (final a in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(a.route);
                },
                child: Row(
                  children: [
                    Container(width: 4, height: 36, decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.label, style: AppText.cardTitle.copyWith(fontSize: 15)),
                          Text(a.hint, style: AppText.caption),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
      );
    },
  );
}
