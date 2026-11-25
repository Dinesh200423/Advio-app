import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../data/backend/backend_config.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/notifications_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/checklists/checklist_routes.dart';
import '../../features/clients/client_routes.dart';
import '../../features/automation/automation_screen.dart';
import '../../features/expenses/expense_routes.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_routes.dart';
import '../../features/team/module_access.dart';
import '../../features/team/team_providers.dart';
import '../../features/team/team_routes.dart';
import '../../features/support/support_routes.dart';
import '../../features/finance/finance_screen.dart';
import '../../features/invoices/invoice_routes.dart';
import '../../features/leads/lead_routes.dart';
import '../../features/quotations/quotation_routes.dart';
import '../../features/projects/project_routes.dart';
import '../../features/settings/more_screen.dart';
import '../../features/tasks/task_routes.dart';
import '../shell/app_shell.dart';
import 'navigator_keys.dart';
import 'routes.dart';
import 'transitions.dart';

const _publicPaths = {Routes.splash, Routes.onboarding, Routes.login, Routes.signup};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect when signing in or out, or when this person's access changes.
  final recheck = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => recheck.value++);
  ref.listen(currentMemberProvider, (_, _) => recheck.value++);
  ref.onDispose(recheck.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: recheck,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (BackendConfig.isConfigured && loc == Routes.signup) return Routes.login;
      if (!auth.loggedIn && !_publicPaths.contains(loc)) return Routes.login;
      if (auth.loggedIn && (loc == Routes.login || loc == Routes.signup || loc == Routes.onboarding)) return Routes.home;
      if (auth.loggedIn && !pathAllowed(loc, canUse: (m) => ref.read(canUseProvider(m)), isFounder: ref.read(isFounderProvider))) return Routes.home;
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: ErrorState(
          title: 'Page not found',
          message: 'We couldn\'t find ${state.uri.path}.',
          retryLabel: 'Go to Home',
          onRetry: () => context.go(Routes.home),
        ),
      ),
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.home, pageBuilder: (_, state) => fadePage(state, const DashboardScreen())),
          GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: Routes.more, pageBuilder: (_, state) => fadePage(state, const MoreScreen())),
          ...leadRoutes,
          ...clientRoutes,
          ...projectRoutes,
          ...taskRoutes,
          ...checklistRoutes,
          ...teamRoutes,
          GoRoute(path: Routes.finance, pageBuilder: (_, state) => fadePage(state, const FinanceScreen())),
          ...invoiceRoutes,
          ...quotationRoutes,
          ...expenseRoutes,
          ...supportRoutes,
          GoRoute(path: Routes.automation, builder: (_, _) => const AutomationScreen()),
          GoRoute(path: Routes.reports, builder: (_, _) => const ReportsScreen()),
          ...settingsRoutes,
        ],
      ),
    ],
  );
});
