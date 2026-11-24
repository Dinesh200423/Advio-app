import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import '../../app/router/transitions.dart';
import 'lead_detail_screen.dart';
import 'lead_form_screen.dart';
import 'quick_add_screen.dart';
import 'leads_screen.dart';

/// Leads list lives in the shell (bottom nav visible); forms are full screen.
final leadRoutes = <RouteBase>[
  GoRoute(
    path: Routes.leads,
    pageBuilder: (_, state) => fadePage(
      state,
      LeadsScreen(dueOnly: state.uri.queryParameters['due'] == '1', initialOwner: state.uri.queryParameters['owner']),
    ),
    routes: [
      GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const LeadFormScreen()),
      GoRoute(path: 'quick', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const QuickAddScreen()),
      GoRoute(
        path: ':id',
        builder: (_, state) => LeadDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => LeadFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
