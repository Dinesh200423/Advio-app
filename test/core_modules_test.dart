import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/features/clients/client_providers.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';
import 'package:freelance_os/features/projects/project_providers.dart';
import 'package:freelance_os/features/tasks/task_providers.dart';

import 'helpers.dart';

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

Future<void> submit(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump(const Duration(milliseconds: 700));
  await settle(tester);
}

void main() {
  group('Leads', () {
    testWidgets('list shows seeded leads; search and status filters work', (tester) async {
      await pumpApp(tester);
      await goTo(tester, '/leads');
      expect(find.text('Leads'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'neha');
      await settle(tester);
      expect(find.text('Neha Verma'), findsOneWidget);
      expect(find.text('Arjun Reddy'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await settle(tester);
      expect(find.text('No leads match'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });

    testWidgets('status chip filters the list', (tester) async {
      await pumpApp(tester);
      await goTo(tester, '/leads');
      await tester.tap(find.text('New  2'));
      await settle(tester);
      expect(find.text('Divya Menon'), findsOneWidget);
      expect(find.text('Neha Verma'), findsNothing);
    });

    testWidgets('add lead form validates, then adds a lead to the list', (tester) async {
      final container = await pumpApp(tester);
      await goTo(tester, '/leads');
      final before = container.read(leadsProvider).length;

      await tester.tap(find.byTooltip('Add lead'));
      await settle(tester);

      // Required-field validation
      await tester.tap(find.widgetWithText(FilledButton, 'Add lead'));
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Zara Test');
      await tester.enterText(find.byType(TextFormField).at(1), 'Testco');
      await tester.enterText(find.byType(TextFormField).at(2), 'zara@testco.com');
      await submit(tester, 'Add lead');

      expect(container.read(leadsProvider).length, before + 1);
      expect(find.text('Zara Test'), findsOneWidget);
      // Automation rule "new lead → follow-up task" fired.
      expect(container.read(tasksProvider).any((t) => t.title == 'Follow up with Zara Test'), isTrue);
      expectNoFlutterErrors(tester);
    });

    testWidgets('detail: tabs, status change, follow-up scheduling, notes, convert', (tester) async {
      final container = await pumpApp(tester);
      await goTo(tester, '/leads');
      await pushTo(tester, '/leads/l1');
      expect(find.text('Neha Verma'), findsOneWidget);

      // Notes tab
      await tester.tap(find.text('Notes'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Sent proposal draft');
      await tester.tap(find.text('Add note'));
      await settle(tester);
      expect(container.read(leadProvider('l1'))!.notes.first.text, 'Sent proposal draft');

      // Follow-ups tab: schedule
      await tester.tap(find.text('Follow-ups'));
      await settle(tester);
      await tester.tap(find.text('Schedule follow-up'));
      await settle(tester);
      await tester.tap(find.text('Meeting'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Schedule'));
      await settle(tester);
      expect(container.read(leadProvider('l1'))!.followUps.any((f) => f.type == FollowUpType.meeting), isTrue);

      // Activity tab shows history
      await tester.tap(find.text('Activity'));
      await settle(tester);
      expect(find.text('Meeting follow-up scheduled'), findsOneWidget);

      // Convert to client
      final clients = container.read(clientsProvider).length;
      await tester.tap(find.text('Convert'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Convert').last);
      await settle(tester);
      expect(container.read(clientsProvider).length, clients + 1);
      expect(container.read(leadProvider('l1'))!.status, LeadStatus.won);
      expectNoFlutterErrors(tester);
    });

    testWidgets('edit and delete a lead', (tester) async {
      final container = await pumpApp(tester);
      await goTo(tester, '/leads');
      await pushTo(tester, '/leads/l3');
      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      expect(find.text('Edit lead'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'Saffron Group');
      await submit(tester, 'Save changes');
      expect(container.read(leadProvider('l3'))!.company, 'Saffron Group');

      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(container.read(leadProvider('l3')), isNull);
      expectNoFlutterErrors(tester);
    });
  });

  group('Clients', () {
    testWidgets('list, search, detail tabs', (tester) async {
      await pumpApp(tester);
      await pushTo(tester, '/clients');
      expect(find.text('Nova Retail Pvt Ltd'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'bloom');
      await settle(tester);
      expect(find.text('Bloom Wellness Studio'), findsOneWidget);
      expect(find.text('Nova Retail Pvt Ltd'), findsNothing);

      await pushTo(tester, '/clients/c1');
      for (final tab in ['Work', 'Billing', 'Notes', 'Overview']) {
        await tester.tap(find.text(tab));
        await settle(tester);
      }
      expectNoFlutterErrors(tester);
    });

    testWidgets('add client via form', (tester) async {
      final container = await pumpApp(tester);
      await pushTo(tester, '/clients');
      final before = container.read(clientsProvider).length;
      await tester.tap(find.text('Add client'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Test Person');
      await tester.enterText(find.byType(TextFormField).at(2), 'test@person.com');
      await submit(tester, 'Add client');
      expect(container.read(clientsProvider).length, before + 1);
    });
  });

  group('Projects', () {
    testWidgets('list filters by status; detail tabs work', (tester) async {
      await pumpApp(tester);
      await goTo(tester, '/projects');
      await tester.tap(find.text('Planned  1'));
      await settle(tester);
      expect(find.text('LMS Portal'), findsOneWidget);
      expect(find.text('E-commerce Redesign'), findsNothing);

      await pushTo(tester, '/projects/p1');
      for (final tab in ['Tasks', 'Files', 'Activity', 'Overview']) {
        await tester.tap(find.text(tab));
        await settle(tester);
      }
      expectNoFlutterErrors(tester);
    });

    testWidgets('milestone toggle changes progress; create project works', (tester) async {
      final container = await pumpApp(tester);
      final p1 = container.read(projectProgressProvider('p1'));
      await goTo(tester, '/projects');
      await pushTo(tester, '/projects/p1');
      await tester.scrollUntilVisible(find.text('Storefront development'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byTooltip('Mark as done').first);
      await tester.pump();
      await tester.tap(find.byTooltip('Mark as done').first);
      await settle(tester);
      expect(container.read(projectProgressProvider('p1')), greaterThan(p1));

      final before = container.read(projectsProvider).length;
      await pushTo(tester, '/projects/new');
      await tester.enterText(find.byType(TextFormField).at(0), 'New Test Project');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Nova Retail Pvt Ltd').last);
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(1), '50000');
      await submit(tester, 'Create project');
      expect(container.read(projectsProvider).length, before + 1);
    });
  });

  group('Tasks', () {
    testWidgets('view chips filter; completing a task updates state', (tester) async {
      final container = await pumpApp(tester);
      await pushTo(tester, '/tasks');
      await tester.tap(find.text('Today  4').first);
      await settle(tester);
      expect(find.text('Send intro deck to Divya (Saffron Kitchen)'), findsOneWidget);
      expect(find.text('Send reminder for INV-2026-017 (GreenLeaf)'), findsNothing);

      final pending = container.read(pendingTasksProvider).length;
      await tester.tap(find.byTooltip('Mark as done').first);
      await settle(tester);
      expect(container.read(pendingTasksProvider).length, pending - 1);
      expectNoFlutterErrors(tester);
    });

    testWidgets('create a task with priority and project', (tester) async {
      final container = await pumpApp(tester);
      await pushTo(tester, '/tasks/new?projectId=p2');
      await tester.enterText(find.byType(TextFormField).at(0), 'Write release notes');
      await tester.tap(find.text('Urgent'));
      await settle(tester);
      await submit(tester, 'Add task');
      final t = container.read(tasksProvider).firstWhere((t) => t.title == 'Write release notes');
      expect(t.priority, Priority.urgent);
      expect(t.projectId, 'p2');
    });

    testWidgets('task detail: change status and complete', (tester) async {
      final container = await pumpApp(tester);
      await pushTo(tester, '/tasks/t1');
      await tester.tap(find.text('Mark as completed'));
      await settle(tester);
      expect(container.read(taskProvider('t1'))!.status, TaskStatus.completed);
      expectNoFlutterErrors(tester);
    });
  });
}
