import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'support_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_form_screen.dart';

final supportRoutes = <RouteBase>[
  GoRoute(
    path: Routes.support,
    builder: (_, _) => const SupportScreen(),
    routes: [
      GoRoute(
        path: 'new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TicketFormScreen(clientId: state.uri.queryParameters['clientId']),
      ),
      GoRoute(
        path: ':id',
        builder: (_, state) => TicketDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => TicketFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
