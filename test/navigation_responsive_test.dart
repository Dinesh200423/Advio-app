import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/features/settings/settings_providers.dart';

import 'helpers.dart';

/// Every route in the app, with seeded ids for the detail screens.
const allRoutes = [
  '/home', '/leads', '/projects', '/finance', '/more',
  '/notifications', '/clients', '/tasks', '/tasks?view=overdue', '/tasks?view=today', '/quotations', '/expenses',
  '/support', '/automation', '/reports', '/settings', '/invoices', '/invoices?status=overdue', '/payments', '/leads?due=1',
  '/settings/profile', '/settings/business', '/settings/currency', '/settings/notifications', '/settings/appearance', '/settings/about',
  '/leads/new', '/leads/l1', '/leads/l1/edit',
  '/clients/new', '/clients/c1', '/clients/c1/edit',
  '/projects/new', '/projects/p1', '/projects/p1/edit',
  '/tasks/new', '/tasks/t1', '/tasks/t1/edit',
  '/quotations/new', '/quotations/q1', '/quotations/q1/edit', '/quotations/q1/preview',
  '/invoices/new', '/invoices/inv14', '/invoices/inv14/edit', '/invoices/inv14/preview', '/invoices/inv14/payment',
  '/expenses/new', '/expenses/e1', '/expenses/e1/edit',
  '/support/new', '/support/tk1', '/support/tk1/edit',
  '/team', '/team/tm1', '/team/tm2', '/team/new', '/team/tm2/edit', '/tasks?assignee=none', '/leads?owner=none',
  '/checklists', '/checklists/cl_p1', '/checklists/cl_p2', '/checklists/cl_p3', '/checklists/cl_p5', '/checklists/cl_p5_m', '/checklists/cl_p7',
  '/checklists/templates', '/checklists/templates/new', '/checklists/templates/tpl_ecom', '/checklists/templates/tpl_maint',
];

Future<void> visitAll(WidgetTester tester, {required Size size, double textScale = 1.0}) async {
  final container = await pumpApp(tester, size: size);
  if (textScale != 1.0) container.read(settingsProvider.notifier).update((s) => s.copyWith(textScale: textScale));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));

  for (final route in allRoutes) {
    await goTo(tester, route);
    final error = tester.takeException();
    expect(error, isNull, reason: '$route @ ${size.width.toInt()}x${size.height.toInt()} scale $textScale → $error');
    expect(find.text('Page not found'), findsNothing, reason: '$route is not routed');
    expect(find.textContaining('not found'), findsNothing, reason: '$route points at a missing record');
  }
}

void main() {
  testWidgets('every route opens cleanly on a small phone (320x568) with large text', (tester) async {
    await visitAll(tester, size: const Size(320, 568), textScale: 1.15);
  });

  testWidgets('every route opens cleanly on a standard phone (390x844)', (tester) async {
    await visitAll(tester, size: const Size(390, 844));
  });

  testWidgets('every route opens cleanly on a tablet (768x1024)', (tester) async {
    await visitAll(tester, size: const Size(768, 1024));
  });

  testWidgets('unknown routes show the not-found page; unknown ids show a missing-record page', (tester) async {
    await pumpApp(tester);
    await goTo(tester, '/definitely/not/a/page');
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('Needs your attention'), findsOneWidget);

    await goTo(tester, '/leads/nope');
    expect(find.text('Lead not found'), findsOneWidget);
    await goTo(tester, '/invoices/nope');
    expect(find.text('Invoice not found'), findsOneWidget);
  });

  testWidgets('signed-out users are sent to login from any protected route', (tester) async {
    await pumpApp(tester, signedIn: false);
    await goTo(tester, '/finance');
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('bottom navigation stays visible on detail pages and highlights the owning tab', (tester) async {
    await pumpApp(tester);
    for (final route in ['/leads/l1', '/projects/p1', '/invoices/inv14', '/clients/c1', '/support/tk1', '/reports']) {
      await goTo(tester, route);
      expect(find.byType(NavigationBar), findsOneWidget, reason: route);
    }
    await goTo(tester, '/invoices/inv14');
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    await goTo(tester, '/clients/c1');
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 4);
    // Full-screen forms intentionally hide it.
    await goTo(tester, '/leads/new');
    expect(find.byType(NavigationBar), findsNothing);
  });
}
