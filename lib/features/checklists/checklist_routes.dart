import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'checklist_detail_screen.dart';
import 'checklists_screen.dart';
import 'template_editor_screen.dart';
import 'templates_screen.dart';

final checklistRoutes = <RouteBase>[
  GoRoute(
    path: Routes.checklists,
    builder: (_, _) => const ChecklistsScreen(),
    routes: [
      // Listed before ':id' so "templates" is never read as a checklist id.
      GoRoute(
        path: 'templates',
        builder: (_, _) => const TemplatesScreen(),
        routes: [
          GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const TemplateEditorScreen()),
          GoRoute(path: ':tid', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => TemplateEditorScreen(id: state.pathParameters['tid'])),
        ],
      ),
      GoRoute(path: ':id', builder: (_, state) => ChecklistDetailScreen(id: state.pathParameters['id']!)),
    ],
  ),
];
