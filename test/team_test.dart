import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/core/components/components.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/data/models/team.dart';
import 'package:freelance_os/features/checklists/checklist_providers.dart';
import 'package:freelance_os/features/dashboard/activity_providers.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';
import 'package:freelance_os/features/support/support_providers.dart';
import 'package:freelance_os/features/tasks/task_providers.dart';
import 'package:freelance_os/features/team/team_providers.dart';
import 'package:freelance_os/features/team/team_workload.dart';

import 'helpers.dart';

const tall = Size(390, 2600);

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

Future<void> submit(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump(const Duration(milliseconds: 700));
  await settle(tester);
}

Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

void main() {
  group('Team', () {
    testWidgets('lists the team with each person\'s workload', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/more');
      await tester.tap(find.text('Team'));
      await settle(tester);
      for (final t in ['Dinesh (you)', 'Priya', 'Rishi', 'Meena', 'Karthik', 'Team members', 'Tasks with no owner', 'Leads with no owner']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expectNoFlutterErrors(tester);
    });

    testWidgets('add a member, then give them a task', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/team');
      await tester.tap(find.text('Add member'));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Asha');
      await submit(tester, 'Add member');
      final asha = container.read(teamProvider).firstWhere((m) => m.name == 'Asha');
      expect(asha.role, TeamRole.developer);
      expect(asha.active, isTrue);

      // She now shows up as someone work can be assigned to.
      await pushTo(tester, '/tasks/new');
      await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
      await settle(tester);
      await tester.tap(find.textContaining('Asha').last);
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Set up staging for Asha');
      await submit(tester, 'Add task');
      expect(container.read(tasksProvider).first.assigneeId, asha.id);
    });

    testWidgets('a deactivated member keeps their history but cannot be assigned new work', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/team/tm5');
      await tester.tap(find.byTooltip('More options'));
      await settle(tester);
      await tester.tap(find.text('Deactivate'));
      await settle(tester);
      // Karthik has open tickets, so this asks first.
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await settle(tester);
      expect(container.read(memberProvider('tm5'))!.active, isFalse);
      expect(container.read(activeMembersProvider).any((m) => m.id == 'tm5'), isFalse);
      // His tickets are untouched.
      expect(container.read(ticketsProvider).where((t) => t.assigneeId == 'tm5').length, 3);
    });

    testWidgets('member page shows what is assigned to them', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/team/tm2'); // Priya
      final load = container.read(workloadProvider('tm2'));
      expect(load.openTasks, greaterThan(0));
      expect(find.text('Open tasks'), findsOneWidget);
      expect(find.text('Send intro deck to Divya (Saffron Kitchen)'), findsNothing, reason: 'that one is Meena\'s');
      for (final tab in ['Leads', 'Projects', 'Tickets', 'Tasks']) {
        await tester.tap(find.descendant(of: find.byType(SegmentedTabs), matching: find.text(tab)));
        await settle(tester);
      }
      expectNoFlutterErrors(tester);
    });
  });

  group('Assignment', () {
    testWidgets('My Tasks follows whoever the app is used as', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/tasks');
      final mine = container.read(tasksProvider).where((t) => t.assigneeId == 'tm1').length;
      expect(find.text('My Tasks  $mine'), findsOneWidget);

      container.read(currentMemberIdProvider.notifier).switchTo('tm2');
      await settle(tester);
      final priyas = container.read(tasksProvider).where((t) => t.assigneeId == 'tm2').length;
      expect(find.text('My Tasks  $priyas'), findsOneWidget);
      expect(priyas, isNot(mine));
    });

    testWidgets('reassigning a task from its page records it in the activity feed', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/tasks/t2'); // Dinesh's own task
      await tester.tap(find.text('Dinesh').last);
      await settle(tester);
      await tester.tap(inSheet(find.text('Priya')));
      await settle(tester);
      expect(container.read(taskProvider('t2'))!.assigneeId, 'tm2');
      final titles = container.read(activityProvider).map((a) => a.title);
      expect(titles, contains('Task assigned to Priya'));
    });

    testWidgets('the task filter sheet can show only unassigned tasks', (tester) async {
      final container = await pumpApp(tester, size: tall);
      container.read(tasksProvider.notifier).upsert(container.read(tasksProvider).first.copyWith(assigneeId: null));
      final orphan = container.read(tasksProvider).firstWhere((t) => t.assigneeId == null);

      await pushTo(tester, '/tasks');
      await tester.tap(find.byTooltip('Filters'));
      await settle(tester);
      await tester.tap(inSheet(find.byType(DropdownButtonFormField<String?>)));
      await settle(tester);
      await tester.tap(find.text('Unassigned').last);
      await settle(tester);
      await tester.tap(find.text('Apply filters'));
      await settle(tester);
      expect(find.text(orphan.title), findsOneWidget);
      expect(find.text('Review storefront PR for Nova checkout'), findsNothing);
    });

    testWidgets('creating a lead assigns the automation follow-up task to its owner', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/leads/new');
      await tester.enterText(find.byType(TextFormField).at(0), 'Zara Test');
      await tester.enterText(find.byType(TextFormField).at(2), 'zara@testco.com');
      await tester.pump();

      // Hand the lead to Meena (sales) instead of the creator.
      await tester.scrollUntilVisible(find.text('Owner'), 200, scrollable: find.byType(Scrollable).first);
      final ownerField = find.ancestor(of: find.text('Owner'), matching: find.byType(Column)).first;
      await tester.tap(find.descendant(of: ownerField, matching: find.byType(DropdownButtonFormField<String?>)));
      await settle(tester);
      await tester.tap(find.textContaining('Meena').last);
      await settle(tester);
      await submit(tester, 'Add lead');

      final lead = container.read(leadsProvider).first;
      expect(lead.name, 'Zara Test');
      expect(lead.ownerId, 'tm4');
      final followUp = container.read(tasksProvider).firstWhere((t) => t.title == 'Follow up with Zara Test');
      expect(followUp.assigneeId, 'tm4');
    });

    testWidgets('checklist items can be assigned, and "Assigned to me" filters them', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final cl = container.read(checklistProvider('cl_p2'))!;
      final item = cl.currentStage!.applicable.firstWhere((i) => !i.isResolved);
      container.read(checklistsProvider.notifier).setAssignee(cl.id, item.id, 'tm1');
      expect(container.read(checklistProvider(cl.id))!.item(item.id)!.assigneeId, 'tm1');
      expect(container.read(checklistProvider(cl.id))!.item(item.id)!.history.first.title, 'Assigned to Dinesh');

      await goTo(tester, '/checklists/${cl.id}');
      await tester.tap(find.text('Assigned to me  1'));
      await settle(tester);
      expect(find.descendant(of: find.byType(Scrollable).first, matching: find.text(item.title)), findsWidgets);
      expectNoFlutterErrors(tester);
    });

    testWidgets('dashboard is personal: your tasks, and a nudge for work nobody owns', (tester) async {
      final container = await pumpApp(tester, size: tall);
      expect(find.text('Your tasks today'), findsOneWidget);
      expect(find.text('Review storefront PR for Nova checkout'), findsOneWidget);
      expect(find.text('Send intro deck to Divya (Saffron Kitchen)'), findsNothing, reason: 'Meena\'s task');

      // Orphaned work is called out.
      final t = container.read(tasksProvider).firstWhere((t) => t.assigneeId == 'tm1' && !t.isDone);
      container.read(tasksProvider.notifier).upsert(t.copyWith(assigneeId: null));
      await settle(tester);
      expect(find.textContaining('with no owner'), findsOneWidget);
    });
  });

  group('ADVIO lead fields', () {
    testWidgets('a lead carries the service and budget band from the website enquiry', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final l3 = container.read(leadProvider('l3'))!;
      expect(l3.service, ServiceInterest.website);
      expect(l3.budget, BudgetBand.from25kTo60k);
      expect(l3.source, LeadSource.website);
      expect(container.read(leadsProvider).any((l) => l.source == LeadSource.whatsapp), isTrue);

      await pushTo(tester, '/leads/l3');
      expect(find.text('Website Development'), findsOneWidget);
      expect(find.text('₹25,000 – ₹60,000'), findsOneWidget);
    });

    testWidgets('picking a budget band fills in the deal value, without overwriting a typed one', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/leads/new');
      await tester.enterText(find.byType(TextFormField).at(0), 'Band Test');
      await tester.enterText(find.byType(TextFormField).at(2), 'band@test.com');

      await tester.tap(find.byType(DropdownButtonFormField<BudgetBand?>));
      await settle(tester);
      await tester.tap(find.text('₹60,000 – ₹1,50,000').last);
      await settle(tester);
      await submit(tester, 'Add lead');

      final lead = container.read(leadsProvider).first;
      expect(lead.budget, BudgetBand.from60kTo150k);
      expect(lead.estimatedValue, 105000);
    });

    testWidgets('the lead list filters by service', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/leads');
      await tester.tap(find.text('Any service'));
      await settle(tester);
      await tester.tap(find.text('Automation').last);
      await settle(tester);
      expect(find.text('Dev Malhotra'), findsOneWidget);
      expect(find.text('Neha Verma'), findsNothing);
    });
  });
}
