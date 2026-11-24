import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'quotation_detail_screen.dart';
import 'quotation_form_screen.dart';
import 'quotation_preview_screen.dart';
import 'quotations_screen.dart';

final quotationRoutes = <RouteBase>[
  GoRoute(
    path: Routes.quotations,
    builder: (_, _) => const QuotationsScreen(),
    routes: [
      GoRoute(
        path: 'new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => QuotationFormScreen(clientId: state.uri.queryParameters['clientId']),
      ),
      GoRoute(
        path: ':id',
        builder: (_, state) => QuotationDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'preview', builder: (_, state) => QuotationPreviewScreen(id: state.pathParameters['id']!)),
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => QuotationFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
