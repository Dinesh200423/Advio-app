import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';
import 'clients_screen.dart';

final clientRoutes = <RouteBase>[
  GoRoute(
    path: Routes.clients,
    builder: (_, _) => const ClientsScreen(),
    routes: [
      GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ClientFormScreen()),
      GoRoute(
        path: ':id',
        builder: (_, state) => ClientDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => ClientFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
