import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/update/app_update.dart';
import '../../core/update/update_prompt.dart';
import '../../data/models/modules.dart';
import '../../features/auth/session_loader.dart';
import '../../features/team/team_providers.dart';
import '../router/routes.dart';
import '../theme/app_text.dart';

/// Persistent frame for every main screen: bottom navigation + global quick-action button.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Keep the lists current while the app is open (a no-op on sample data).
    ref.read(liveUpdatesProvider);
    // Once per launch, offer a newer version if there is one. A failed check stays silent.
    ref.listenManual(availableUpdateProvider, (_, next) {
      final update = next.asData?.value;
      if (update == null || ref.read(updatePromptedProvider)) return;
      ref.read(updatePromptedProvider.notifier).markShown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showUpdateDialog(context, ref, update, installed: ref.read(installedVersionProvider).asData?.value ?? '');
      });
    }, fireImmediately: true);
  }

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

    // Only the tabs this person has access to. Home and More are always there.
    final canUse = ref.watch(currentMemberProvider);
    bool can(AppModule m) => canUse == null || canUse.canUse(m);
    final tabs = [
      for (var i = 0; i < _tabs.length; i++)
        if (switch (_tabs[i].route) {
          Routes.leads => can(AppModule.leads),
          Routes.projects => can(AppModule.projects),
          Routes.finance => can(AppModule.invoices) || can(AppModule.quotations) || can(AppModule.expenses),
          _ => true,
        })
          (original: i, tab: _tabs[i]),
    ];
    final owner = Routes.tabIndexFor(path);
    final found = tabs.indexWhere((t) => t.original == owner);
    final index = found >= 0 ? found : tabs.length - 1;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showFab = Routes.tabRoots.contains(path) && !keyboardOpen;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: widget.child,
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
                  if (i == index && path == tabs[i].tab.route) return;
                  context.go(tabs[i].tab.route);
                },
                destinations: [
                  for (final t in tabs)
                    NavigationDestination(
                      icon: Icon(t.tab.icon),
                      selectedIcon: Icon(t.tab.selected, color: AppColors.primary),
                      label: t.tab.label,
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
      final me = ProviderScope.containerOf(context).read(currentMemberProvider);
      final actions = [
        (module: AppModule.leads, icon: Icons.person_add_alt_1_rounded, label: 'Add Lead', hint: 'Capture a new prospect', color: AppColors.primary, route: Routes.leadNew),
        (module: AppModule.tasks, icon: Icons.task_alt_rounded, label: 'Add Task', hint: 'Plan something to do', color: AppColors.secondary, route: Routes.taskNew()),
        (module: AppModule.projects, icon: Icons.create_new_folder_rounded, label: 'Create Project', hint: 'Start a client project', color: AppColors.success, route: Routes.projectNew()),
        (module: AppModule.invoices, icon: Icons.receipt_long_rounded, label: 'Create Invoice', hint: 'Bill a client', color: AppColors.warning, route: Routes.invoiceNew()),
      ].where((a) => me == null || me.canUse(a.module)).toList();
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
