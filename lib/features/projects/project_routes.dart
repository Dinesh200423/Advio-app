import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import '../../app/router/transitions.dart';
import 'project_detail_screen.dart';
import 'project_form_screen.dart';
import 'projects_screen.dart';

final projectRoutes = <RouteBase>[
  GoRoute(
    path: Routes.projects,
    pageBuilder: (_, state) => fadePage(state, const ProjectsScreen()),
    routes: [
      GoRoute(
        path: 'new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ProjectFormScreen(clientId: state.uri.queryParameters['clientId']),
      ),
      GoRoute(
        path: ':id',
        builder: (_, state) => ProjectDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => ProjectFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
