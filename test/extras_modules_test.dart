import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/core/components/states.dart';
import 'package:freelance_os/core/utils/formatters.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/features/auth/auth_providers.dart';
import 'package:freelance_os/features/automation/automation_providers.dart';
import 'package:freelance_os/features/settings/settings_providers.dart';
import 'package:freelance_os/features/support/support_providers.dart';

import 'helpers.dart';

const tall = Size(390, 2400);

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

Future<void> submit(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump(const Duration(milliseconds: 700));
  await settle(tester);
}

void main() {
  group('Support', () {
    testWidgets('dashboard lists tickets; status filter and plans tab work', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/support');
      expect(find.text('Open tickets'), findsOneWidget);
      expect(find.text('Checkout payment webhook failing intermittently'), findsOneWidget);

      await tester.tap(find.text('Open  2'));
      await settle(tester);
      expect(find.text('Push notifications not delivered on iOS'), findsOneWidget);
      expect(find.text('Checkout payment webhook failing intermittently'), findsNothing);

      await tester.tap(find.text('Maintenance plans'));
      await settle(tester);
      expect(find.text('Growth Care Plan'), findsOneWidget);

      // Pausing a plan lowers recurring revenue.
      final before = container.read(monthlyRecurringProvider);
      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      expect(container.read(monthlyRecurringProvider), lessThan(before));
      expectNoFlutterErrors(tester);
    });

    testWidgets('create a ticket, add an update and resolve it', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/support/new');

      await tester.tap(find.widgetWithText(FilledButton, 'Create ticket'));
      await tester.pump();
      expect(find.text('Please choose a client'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Zenith Fintech').last);
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Footer link is broken');
      await tester.tap(find.text('High'));
      await settle(tester);
      await submit(tester, 'Create ticket');

      final created = container.read(ticketsProvider).first;
      expect(created.title, 'Footer link is broken');
      expect(created.priority, Priority.high);
      expect(created.number, 'TKT-1007');

      await pushTo(tester, '/support/${created.id}');
      await tester.enterText(find.byType(TextField).first, 'Fixed and deployed');
      await tester.tap(find.text('Add note'));
      await settle(tester);
      expect(container.read(ticketProvider(created.id))!.notes.last.text, 'Fixed and deployed');

      await tester.tap(find.text('Mark as resolved'));
      await settle(tester);
      expect(container.read(ticketProvider(created.id))!.status, TicketStatus.resolved);
      expect(find.text('Reopen ticket'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });
  });

  group('Automation', () {
    testWidgets('rules list renders and toggling updates state', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/automation');
      expect(find.text('New lead follow-up'), findsOneWidget);
      expect(find.text('Weekly business summary'), findsOneWidget);
      expect(container.read(automationProvider).where((r) => r.enabled).length, 5);

      await tester.tap(find.byType(Switch).last); // weekly summary, currently off
      await settle(tester);
      expect(container.read(automationProvider).where((r) => r.enabled).length, 6);
      expectNoFlutterErrors(tester);
    });

    testWidgets('turning off the overdue-invoice rule removes that reminder from the dashboard', (tester) async {
      await pumpApp(tester, size: tall);
      expect(find.textContaining('overdue invoice'), findsOneWidget);

      await pushTo(tester, '/automation');
      await tester.tap(find.byType(Switch).at(3));
      await settle(tester);
      await goTo(tester, '/home');
      expect(find.textContaining('overdue invoice'), findsNothing);
    });
  });

  group('Reports', () {
    testWidgets('shows every report section and reloads when the range changes', (tester) async {
      await pumpApp(tester, size: const Size(390, 4200));
      await pushTo(tester, '/reports');
      for (final t in ['Net profit', 'Monthly revenue', 'Monthly expenses', 'Profit summary', 'Lead conversion', 'Project status', 'Outstanding payments']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }

      await tester.tap(find.text('3 months'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonBox), findsWidgets); // loading state
      await tester.pump(const Duration(milliseconds: 800));
      await settle(tester);
      expect(find.text('Net profit'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });
  });

  group('Settings', () {
    testWidgets('hub lists every section', (tester) async {
      await pumpApp(tester);
      await pushTo(tester, '/settings');
      for (final t in ['Profile', 'Business information', 'Currency', 'Notifications', 'Appearance', 'App information', 'Log out']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
    });

    testWidgets('profile edit updates the greeting name', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/settings/profile');
      await tester.enterText(find.byType(TextFormField).first, 'Dinesh Raj');
      await submit(tester, 'Save');
      expect(container.read(settingsProvider).name, 'Dinesh Raj');
      await goTo(tester, '/home');
      expect(find.textContaining('Dinesh 👋'), findsOneWidget);
    });

    testWidgets('changing currency re-formats amounts everywhere', (tester) async {
      final container = await pumpApp(tester);
      await pushTo(tester, '/settings/currency');
      await tester.tap(find.text('US Dollar'));
      await settle(tester);
      expect(container.read(settingsProvider).currency, 'USD');
      expect(formatMoney(125000, 'USD'), r'$125,000');

      await goTo(tester, '/finance');
      expect(find.textContaining(r'$'), findsWidgets);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('notification toggles and text size persist in settings', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/settings/notifications');
      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      expect(container.read(settingsProvider).pushNotifications, isFalse);

      await pushTo(tester, '/settings/appearance');
      await tester.tap(find.text('Large'));
      await settle(tester);
      expect(container.read(settingsProvider).textScale, 1.15);
      expectNoFlutterErrors(tester);
    });

    testWidgets('logout returns to the login screen', (tester) async {
      final container = await pumpApp(tester);
      await pushTo(tester, '/settings');
      await tester.scrollUntilVisible(find.text('Log out'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Log out'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await settle(tester);
      expect(container.read(authProvider).loggedIn, isFalse);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
