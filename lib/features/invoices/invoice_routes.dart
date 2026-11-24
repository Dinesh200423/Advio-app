import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import '../../data/models/enums.dart';
import 'invoice_detail_screen.dart';
import 'invoice_form_screen.dart';
import 'invoice_preview_screen.dart';
import 'invoices_screen.dart';
import 'payment_form_screen.dart';
import 'payments_screen.dart';

final invoiceRoutes = <RouteBase>[
  GoRoute(
    path: Routes.invoices,
    builder: (_, state) {
      final name = state.uri.queryParameters['status'];
      final status = InvoiceStatus.values.where((s) => s.name == name).firstOrNull;
      return InvoicesScreen(initialStatus: status);
    },
    routes: [
      GoRoute(
        path: 'new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => InvoiceFormScreen(
          clientId: state.uri.queryParameters['clientId'],
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      GoRoute(
        path: ':id',
        builder: (_, state) => InvoiceDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'preview', builder: (_, state) => InvoicePreviewScreen(id: state.pathParameters['id']!)),
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => InvoiceFormScreen(id: state.pathParameters['id'])),
          GoRoute(path: 'payment', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => PaymentFormScreen(invoiceId: state.pathParameters['id']!)),
        ],
      ),
    ],
  ),
  GoRoute(path: Routes.payments, builder: (_, _) => const PaymentsScreen()),
];
