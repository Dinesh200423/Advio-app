import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'member_detail_screen.dart';
import 'member_form_screen.dart';
import 'team_screen.dart';

final teamRoutes = <RouteBase>[
  GoRoute(
    path: Routes.team,
    builder: (_, _) => const TeamScreen(),
    routes: [
      GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const MemberFormScreen()),
      GoRoute(
        path: ':id',
        builder: (_, state) => MemberDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => MemberFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
