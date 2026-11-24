import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';
import 'tasks_screen.dart';

final taskRoutes = <RouteBase>[
  GoRoute(
    path: Routes.tasks,
    builder: (_, state) => TasksScreen(
      initialView: TaskView.fromName(state.uri.queryParameters['view']),
      initialAssignee: state.uri.queryParameters['assignee'],
    ),
    routes: [
      GoRoute(
        path: 'new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TaskFormScreen(projectId: state.uri.queryParameters['projectId']),
      ),
      GoRoute(
        path: ':id',
        builder: (_, state) => TaskDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => TaskFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
