import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/core/components/components.dart';
import 'package:freelance_os/data/mock/mock_checklist_templates.dart';
import 'package:freelance_os/features/checklists/checklist_detail_screen.dart';
import 'package:freelance_os/data/models/checklist.dart';
import 'package:freelance_os/features/checklists/checklist_providers.dart';
import 'package:freelance_os/features/checklists/widgets/item_tile.dart';
import 'package:freelance_os/features/settings/settings_providers.dart';
import 'package:freelance_os/features/checklists/widgets/template_card.dart';

import 'helpers.dart';

const tall = Size(390, 3000);

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

/// A fresh Static Website checklist on project p4 and its screen opened.
Future<ProjectChecklist> openFreshChecklist(WidgetTester tester, ProviderContainer c) async {
  final cl = c.read(checklistsProvider.notifier).createFromTemplate(MockChecklistTemplates.staticWebsite(), projectId: 'p4');
  await goTo(tester, '/checklists/${cl.id}');
  return cl;
}

ChecklistItem item(ProviderContainer c, String checklistId, String title) =>
    c.read(checklistProvider(checklistId))!.allItems.firstWhere((i) => i.title == title);

Future<void> pickStatus(WidgetTester tester, String label) async {
  await tester.tap(inSheet(find.text(label)));
  await settle(tester);
}

void main() {
  group('Checklist overview', () {
    testWidgets('the list shows what needs attention across projects', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/more');
      await tester.tap(find.text('Delivery checklists'));
      await settle(tester);
      for (final t in ['Active checklists', 'Waiting on client', 'Blocked stages', 'Overdue items', 'E-commerce Redesign', 'Booking App']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expectNoFlutterErrors(tester);
    });

    testWidgets('a project page lists its checklists, or offers to start one', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/projects');
      await pushTo(tester, '/projects/p1');
      await tester.tap(find.text('Checklist').first);
      await settle(tester);
      expect(find.text('Ecommerce / Dynamic Website'), findsOneWidget);

      // p4 has none yet: start one from a template.
      await goTo(tester, '/projects');
      await pushTo(tester, '/projects/p4');
      await tester.tap(find.text('Checklist').first);
      await settle(tester);
      expect(find.text('No delivery checklist yet'), findsOneWidget);
      await tester.tap(find.text('Start a checklist'));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Create checklist'));
      await tester.pump();
      expect(find.text('Choose a template'), findsOneWidget, reason: 'template is required');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Mobile Application Development').last);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create checklist'));
      await settle(tester);

      final created = container.read(projectChecklistsProvider('p4'));
      expect(created.length, 1);
      expect(created.single.stages.length, 9);
      expect(created.single.progress, 0);
      expect(find.text('Stages'), findsOneWidget, reason: 'opened the new checklist');
      expectNoFlutterErrors(tester);
    });

    testWidgets('detail shows the overview numbers, current stage and next action', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/cl_p1');
      final cl = container.read(checklistProvider('cl_p1'))!;
      for (final t in ['Completed items', 'Pending items', 'Required done', 'Waiting on client', 'Blocked stages', 'Overdue items', 'Stage progress', 'Blocked']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('${cl.requiredDone}/${cl.requiredTotal}'), findsOneWidget);
      expect(find.textContaining('Payment Gateway and Compliance'), findsWidgets, reason: 'current stage');
      expect(find.textContaining('NEXT'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });

    testWidgets('stages expand and collapse; the current one opens by itself', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final cl = await openFreshChecklist(tester, container);
      final first = cl.stages.first.items.first.title;
      Finder tile(String t) => find.descendant(of: find.byType(ChecklistItemTile), matching: find.text(t));
      expect(tile(first), findsOneWidget, reason: 'current stage starts open');
      expect(tile(cl.stages[1].items.first.title), findsNothing, reason: 'other stages start closed');

      await tester.tap(find.text('Contract and Kickoff'));
      await settle(tester);
      expect(find.text(cl.stages[1].items.first.title), findsOneWidget);

      // Only some stages are open, so the shortcut offers to open the rest.
      expect(find.text('Collapse all'), findsNothing);
      await tester.tap(find.text('Expand all'));
      await settle(tester);
      expect(tile(first), findsOneWidget);
      await tester.tap(find.text('Collapse all'));
      await settle(tester);
      expect(tile(first), findsNothing);
      expectNoFlutterErrors(tester);
    });

    testWidgets('filters narrow the stages to waiting-on-client items, which are flagged', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/cl_p1');
      // The filter chips scroll sideways; bring this one into view first.
      await tester.scrollUntilVisible(find.text('Waiting on client  1'), 120, scrollable: find.descendant(of: find.byType(FilterChipRow<ItemFilter>), matching: find.byType(Scrollable)));
      await tester.tap(find.text('Waiting on client  1'));
      await settle(tester);
      expect(find.text('Finalize payment gateway'), findsOneWidget);
      expect(find.text('Waiting on client'), findsWidgets);
      expect(find.text('Collect product catalogue'), findsNothing, reason: 'completed items are filtered out');
      expectNoFlutterErrors(tester);
    });
  });

  group('Updating items', () {
    testWidgets('Done needs the evidence the item asks for, then progress moves', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final cl = await openFreshChecklist(tester, container);
      const title = 'Collect client requirements';
      expect(container.read(checklistProvider(cl.id))!.progress, 0);

      await tester.tap(find.byTooltip('Status: To Do. Tap to change').first);
      await settle(tester);
      await pickStatus(tester, 'Done');
      expect(find.text('Add evidence to finish'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save & mark done'));
      await tester.pump();
      expect(find.text('Write a short note'), findsOneWidget);
      expect(item(container, cl.id, title).status, ChecklistItemStatus.todo);

      await tester.enterText(inSheet(find.byType(TextFormField)), 'Call notes saved in Drive');
      await tester.tap(find.widgetWithText(FilledButton, 'Save & mark done'));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      final done = item(container, cl.id, title);
      expect(done.status, ChecklistItemStatus.done);
      expect(done.evidence.single.value, 'Call notes saved in Drive');
      expect(container.read(checklistProvider(cl.id))!.progress, greaterThan(0));
      expect(find.text('Done ${DateTime.now().day} ${_month(DateTime.now())}'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });

    testWidgets('Skipped needs a reason', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final cl = await openFreshChecklist(tester, container);
      const title = 'Collect client requirements';

      await tester.tap(find.byTooltip('Status: To Do. Tap to change').first);
      await settle(tester);
      await pickStatus(tester, 'Skipped');
      expect(find.textContaining('Skip "$title"'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Skip item'));
      await tester.pump();
      expect(find.text('A reason is required to skip an item'), findsOneWidget);
      expect(item(container, cl.id, title).status, ChecklistItemStatus.todo);

      await tester.enterText(inSheet(find.byType(TextFormField)), 'Requirements were agreed in the proposal');
      await tester.tap(find.widgetWithText(FilledButton, 'Skip item'));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      final skipped = item(container, cl.id, title);
      expect(skipped.status, ChecklistItemStatus.skipped);
      expect(skipped.skipReason, 'Requirements were agreed in the proposal');
      expect(find.textContaining('Skipped: Requirements were agreed'), findsOneWidget);
    });

    testWidgets('Not Applicable removes an item from progress; Waiting on Client flags it', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final cl = await openFreshChecklist(tester, container);
      final requiredBefore = container.read(checklistProvider(cl.id))!.requiredTotal;

      await tester.tap(find.byTooltip('Status: To Do. Tap to change').first);
      await settle(tester);
      await pickStatus(tester, 'Not Applicable');
      expect(container.read(checklistProvider(cl.id))!.requiredTotal, requiredBefore - 1);

      await tester.tap(find.byTooltip('Status: To Do. Tap to change').first);
      await settle(tester);
      await pickStatus(tester, 'Waiting on Client');
      final after = container.read(checklistProvider(cl.id))!;
      expect(after.waitingCount, 1);
      expect(after.blockedStageCount, 1);
      expect(find.text('Waiting on client'), findsWidgets);
      expectNoFlutterErrors(tester);
    });

    testWidgets('item details: notes, due date, evidence and history', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final cl = await openFreshChecklist(tester, container);
      const title = 'Send proposal and quotation'; // file evidence

      await tester.tap(find.text(title));
      await settle(tester);
      for (final t in ['Evidence', 'Notes', 'Activity', 'Due date']) {
        expect(inSheet(find.text(t)), findsWidgets, reason: t);
      }

      // Note
      await tester.enterText(inSheet(find.byType(TextField)), 'Sent v2 of the proposal');
      await tester.tap(inSheet(find.text('Add note')));
      await settle(tester);
      expect(item(container, cl.id, title).notes.single.text, 'Sent v2 of the proposal');

      // Due date: clear, then set again
      await tester.tap(inSheet(find.text('Clear')));
      await settle(tester);
      expect(item(container, cl.id, title).dueDate, isNull);
      await tester.tap(inSheet(find.text('Set date')));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(item(container, cl.id, title).dueDate, isNotNull);

      // Evidence (simulated file)
      expect(inSheet(find.text('Required: Proposal document (file)')), findsOneWidget);
      await tester.tap(inSheet(find.text('Add evidence')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add evidence'));
      await tester.pump();
      expect(find.text('Choose a file to continue'), findsOneWidget);
      await tester.tap(find.text('Choose file'));
      await settle(tester);
      await tester.tap(find.text('proposal-document.pdf'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add evidence'));
      await settle(tester);
      expect(item(container, cl.id, title).evidence.single.value, 'proposal-document.pdf');
      expect(inSheet(find.text('proposal-document.pdf')), findsWidgets, reason: 'shown on the evidence card and in the history');

      // History records all of it
      final history = item(container, cl.id, title).history.map((h) => h.title).toList();
      expect(history, containsAll(['Note added', 'Due date removed', 'File evidence added']));
      expectNoFlutterErrors(tester);
    });

    testWidgets('a recurring checklist shows its period and can start next month', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/cl_p5_m');
      final period = container.read(checklistProvider('cl_p5_m'))!.servicePeriod!;
      expect(find.textContaining(period), findsWidgets);

      final before = container.read(checklistsProvider).length;
      await tester.tap(find.text('Start next month\'s checklist'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await settle(tester);
      expect(container.read(checklistsProvider).length, before + 1);
      expectNoFlutterErrors(tester);
    });
  });

  group('Small screens', () {
    testWidgets('every sheet fits a 320px phone with large text', (tester) async {
      final container = await pumpApp(tester, size: const Size(320, 640));
      container.read(settingsProvider.notifier).update((s) => s.copyWith(textScale: 1.15));
      final cl = await openFreshChecklist(tester, container);

      Future<void> dismiss() async {
        await tester.tapAt(const Offset(160, 8));
        await settle(tester);
      }

      final firstItem = find.descendant(of: find.byType(ChecklistItemTile), matching: find.text('Collect client requirements'));
      await tester.scrollUntilVisible(firstItem, 150, scrollable: find.byType(Scrollable).first);
      await settle(tester);

      // Item details
      await tester.tap(firstItem);
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expectNoFlutterErrors(tester);
      await dismiss();

      // Status picker, skip reason, evidence
      await tester.tap(find.byTooltip('Status: To Do. Tap to change').first);
      await settle(tester);
      expectNoFlutterErrors(tester);
      await pickStatus(tester, 'Skipped');
      expectNoFlutterErrors(tester);
      await dismiss();
      await tester.tap(find.byTooltip('Status: To Do. Tap to change').first);
      await settle(tester);
      await pickStatus(tester, 'Done');
      expect(find.text('Add evidence to finish'), findsOneWidget);
      expectNoFlutterErrors(tester);
      await dismiss();
      expect(item(container, cl.id, 'Collect client requirements').status, ChecklistItemStatus.todo);

      // New checklist sheet and template item sheet
      await goTo(tester, '/checklists');
      await tester.tap(find.text('New checklist'));
      await settle(tester);
      expectNoFlutterErrors(tester);
      await dismiss();

      await goTo(tester, '/checklists/templates/tpl_static');
      await tester.scrollUntilVisible(find.text('1. Discovery and Proposal'), 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('1. Discovery and Proposal'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Collect client requirements'), 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Collect client requirements'));
      await settle(tester);
      expect(find.text('Edit checklist item'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });
  });

  group('Template library', () {
    testWidgets('lists all six families and filters by category', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/templates');
      for (final t in ['Static Website Development', 'Ecommerce / Dynamic Website', 'CRM and Automation Development', 'Mobile Application Development', 'Workflow Automation', 'Monthly Support and Maintenance']) {
        expect(find.byWidgetPredicate((w) => w is TemplateCard && w.template.name == t), findsOneWidget, reason: t);
      }
      expect(find.text('10 stages  ·  ${MockChecklistTemplates.staticWebsite().itemCount} items'), findsOneWidget);

      await tester.tap(find.text('Mobile App'));
      await settle(tester);
      expect(find.text('Mobile Application Development'), findsOneWidget);
      expect(find.text('Workflow Automation'), findsNothing);
      expectNoFlutterErrors(tester);
    });

    testWidgets('duplicate and delete (with confirmation) leave project checklists alone', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/templates');
      final before = container.read(templatesProvider).length;
      final checklistsBefore = container.read(checklistsProvider);

      Finder onCard(String template, String action) =>
          find.descendant(of: find.widgetWithText(TemplateCard, template), matching: find.text(action));

      await tester.tap(onCard('Mobile Application Development', 'Duplicate'));
      await settle(tester);
      expect(container.read(templatesProvider).length, before + 1);
      expect(container.read(templatesProvider).any((t) => t.name == 'Mobile Application Development (Copy)'), isTrue);

      // Ecommerce is used by a project: the dialog says that project keeps its copy.
      await tester.tap(onCard('Ecommerce / Dynamic Website', 'Delete'));
      await settle(tester);
      expect(find.textContaining('keep their own copy'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(container.read(templatesProvider).length, before);
      expect(container.read(templatesProvider).any((t) => t.id == 'tpl_ecom'), isFalse);

      final checklistsAfter = container.read(checklistsProvider);
      expect(checklistsAfter.length, checklistsBefore.length);
      expect(checklistsAfter.fold<int>(0, (s, c) => s + c.allItems.length), checklistsBefore.fold<int>(0, (s, c) => s + c.allItems.length));
      expectNoFlutterErrors(tester);
    });

    testWidgets('create a template with stages and items, reorder stages, and save', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/templates');
      final before = container.read(templatesProvider).length;
      await tester.tap(find.text('New template'));
      await settle(tester);

      // Validation
      await tester.tap(find.widgetWithText(FilledButton, 'Create template'));
      await tester.pump();
      expect(find.text('Template name is required'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'SEO Audit');
      await tester.tap(find.widgetWithText(FilledButton, 'Create template'));
      await tester.pump();
      expect(find.text('Add at least one stage'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      Future<void> addStage(String name, String itemTitle) async {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Add stage'));
        await settle(tester);
        await tester.enterText(inSheet(find.byType(TextFormField)).first, name);
        await tester.tap(find.widgetWithText(FilledButton, 'Add stage'));
        await settle(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Add item').last);
        await settle(tester);
        await tester.enterText(inSheet(find.byType(TextFormField)).first, itemTitle);
        await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
        await settle(tester);
      }

      await addStage('Audit', 'Crawl the site');
      await addStage('Report', 'Write findings');

      // Move "Report" above "Audit" with the stage menu.
      await tester.tap(find.byTooltip('Stage options').last);
      await settle(tester);
      await tester.tap(find.text('Move up'));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Create template'));
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);

      final templates = container.read(templatesProvider);
      expect(templates.length, before + 1);
      final saved = templates.firstWhere((t) => t.name == 'SEO Audit');
      expect(saved.stages.map((s) => s.name).toList(), ['Report', 'Audit']);
      expect(saved.itemCount, 2);
      expectNoFlutterErrors(tester);
    });

    testWidgets('a stage without items cannot be saved', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/templates/new');
      await tester.enterText(find.byType(TextFormField).first, 'Half done');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add stage'));
      await settle(tester);
      await tester.enterText(inSheet(find.byType(TextFormField)).first, 'Empty stage');
      await tester.tap(find.widgetWithText(FilledButton, 'Add stage'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create template'));
      await tester.pump();
      expect(find.textContaining('has no items yet'), findsOneWidget);
    });

    testWidgets('editing a template never changes checklists already started from it', (tester) async {
      final container = await pumpApp(tester, size: tall);
      final before = container.read(checklistProvider('cl_p7'))!;
      final itemsBefore = before.allItems.length;
      final stagesBefore = before.stages.map((s) => s.name).toList();

      await goTo(tester, '/checklists/templates/tpl_static');
      expect(find.textContaining('started from this template'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Brochure Website (v2)');
      // Remove a stage from the template.
      await tester.tap(find.byTooltip('Stage options').first);
      await settle(tester);
      await tester.tap(find.text('Delete stage'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);

      final template = container.read(templatesProvider).firstWhere((t) => t.id == 'tpl_static');
      expect(template.name, 'Brochure Website (v2)');
      expect(template.stageCount, 9);

      final after = container.read(checklistProvider('cl_p7'))!;
      expect(after.allItems.length, itemsBefore);
      expect(after.stages.map((s) => s.name).toList(), stagesBefore);
      expect(after.templateName, 'Static Website Development');
      expectNoFlutterErrors(tester);
    });

    testWidgets('leaving the editor with unsaved changes asks first', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/checklists/templates');
      await tester.tap(find.text('Edit').first);
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Changed my mind');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await settle(tester);
      expect(find.text('Edit template'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await settle(tester);
      expect(find.text('Checklist templates'), findsOneWidget);
    });
  });
}

String _month(DateTime d) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];
