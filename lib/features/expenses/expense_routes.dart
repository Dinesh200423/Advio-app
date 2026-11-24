import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';
import 'expenses_screen.dart';

final expenseRoutes = <RouteBase>[
  GoRoute(
    path: Routes.expenses,
    builder: (_, _) => const ExpensesScreen(),
    routes: [
      GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ExpenseFormScreen()),
      GoRoute(
        path: ':id',
        builder: (_, state) => ExpenseDetailScreen(id: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => ExpenseFormScreen(id: state.pathParameters['id'])),
        ],
      ),
    ],
  ),
];
