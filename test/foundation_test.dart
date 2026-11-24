import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('splash → onboarding → login → dashboard', (tester) async {
    await pumpApp(tester, signedIn: false);
    expect(find.text('Everything in one place'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('👋'), findsOneWidget);
    expectNoFlutterErrors(tester);
  });

  testWidgets('login validates required fields', (tester) async {
    await pumpApp(tester, signedIn: false);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('dashboard renders all sections without overflow', (tester) async {
    await pumpApp(tester);
    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.text('Total clients'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    for (final label in ['Revenue vs expenses', 'Your tasks today', 'Outstanding invoices', 'Recent leads', 'Recent activity']) {
      await tester.scrollUntilVisible(find.text(label), 400, scrollable: scrollable);
      expect(find.text(label), findsOneWidget);
    }
    expectNoFlutterErrors(tester);
  });

  testWidgets('bottom navigation switches tabs and More lists modules', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    for (final label in ['Clients', 'Tasks', 'Quotations', 'Expenses', 'Support & Maintenance', 'Automation', 'Reports', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expectNoFlutterErrors(tester);
  });

  testWidgets('quick-action sheet opens from the global button', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Quick actions'));
    await tester.pumpAndSettle();
    for (final label in ['Add Lead', 'Add Task', 'Create Project', 'Create Invoice']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });
}
