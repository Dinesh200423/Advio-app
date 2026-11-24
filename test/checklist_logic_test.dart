import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/mock/mock_checklist_templates.dart';
import 'package:freelance_os/data/models/checklist.dart';
import 'package:freelance_os/features/checklists/checklist_providers.dart';
import 'package:freelance_os/features/dashboard/activity_providers.dart';

ChecklistItem item(String id, ChecklistItemStatus s, {bool req = true, EvidenceType ev = EvidenceType.none}) =>
    ChecklistItem(id: id, title: id, isRequired: req, status: s, evidenceType: ev);

ChecklistStage stage(String id, List<ChecklistItem> items) => ChecklistStage(id: id, name: id, items: items);

void main() {
  const todo = ChecklistItemStatus.todo;
  const done = ChecklistItemStatus.done;

  group('templates', () {
    test('all six families exist with the stage counts from the brief', () {
      final t = {for (final x in MockChecklistTemplates.all()) x.category: x};
      expect(t.length, 6);
      expect(t[ServiceCategory.staticWebsite]!.stageCount, 10);
      expect(t[ServiceCategory.ecommerce]!.stageCount, 13);
      expect(t[ServiceCategory.crm]!.stageCount, 11);
      expect(t[ServiceCategory.mobileApp]!.stageCount, 9);
      expect(t[ServiceCategory.workflow]!.stageCount, 7);
      expect(t[ServiceCategory.maintenance]!.stageCount, 6);
      expect(t[ServiceCategory.maintenance]!.isRecurring, isTrue);
    });

    test('every template has unique ids and a due offset on each item', () {
      for (final t in MockChecklistTemplates.all()) {
        final ids = [for (final s in t.stages) s.id, for (final s in t.stages) ...s.items.map((i) => i.id)];
        expect(ids.toSet().length, ids.length, reason: t.name);
        expect(t.stages.expand((s) => s.items).every((i) => i.dueOffsetDays != null), isTrue, reason: t.name);
      }
    });
  });

  group('progress rules', () {
    test('optional items never block a stage', () {
      final s = stage('s', [item('a', done), item('b', todo, req: false)]);
      expect(s.isComplete, isTrue);
      expect(s.status, StageStatus.completed);
      expect(s.progress, 1);
    });

    test('Not Applicable items are excluded from progress', () {
      final s = stage('s', [item('a', done), item('b', ChecklistItemStatus.notApplicable), item('c', todo)]);
      expect(s.totalCount, 2);
      expect(s.requiredTotal, 2);
      expect(s.progress, 0.5);
    });

    test('a skipped item counts as resolved', () {
      final s = stage('s', [item('a', done), item('b', ChecklistItemStatus.skipped)]);
      expect(s.isComplete, isTrue);
    });

    test('a required item waiting on the client blocks the stage; an optional one does not', () {
      final blocked = stage('s', [item('a', ChecklistItemStatus.waitingClient), item('b', todo)]);
      expect(blocked.status, StageStatus.blocked);
      final fine = stage('s', [item('a', ChecklistItemStatus.doing), item('b', ChecklistItemStatus.waitingClient, req: false)]);
      expect(fine.status, StageStatus.inProgress);
    });

    test('stage status moves Not Started → In Progress → Completed', () {
      expect(stage('s', [item('a', todo), item('b', todo)]).status, StageStatus.notStarted);
      expect(stage('s', [item('a', done), item('b', todo)]).status, StageStatus.inProgress);
      expect(stage('s', [item('a', done), item('b', done)]).status, StageStatus.completed);
    });

    test('a stage made only of optional items completes when they are all resolved', () {
      expect(stage('s', [item('a', todo, req: false)]).isComplete, isFalse);
      expect(stage('s', [item('a', done, req: false)]).isComplete, isTrue);
    });

    test('overall progress, counts, current stage and next action', () {
      final cl = ProjectChecklist(
        id: 'c',
        projectId: 'p',
        templateId: 't',
        templateName: 'T',
        category: ServiceCategory.crm,
        createdAt: DateTime.now(),
        stages: [
          stage('one', [item('a', done), item('b', done)]),
          stage('two', [item('c', done), item('d', ChecklistItemStatus.waitingClient), item('e', ChecklistItemStatus.doing)]),
          stage('three', [item('f', todo), item('g', todo, req: false)]),
          stage('na', [item('h', ChecklistItemStatus.notApplicable)]),
        ],
      );
      expect(cl.activeStages.length, 3, reason: 'a stage that is entirely N/A is ignored');
      expect(cl.requiredTotal, 6);
      expect(cl.requiredDone, 3);
      expect(cl.progress, closeTo(0.5, 1e-9));
      expect(cl.waitingCount, 1);
      expect(cl.blockedStageCount, 1);
      expect(cl.pendingCount, 4); // d, e, f, g
      expect(cl.currentStage!.id, 'two');
      expect(cl.nextAction!.id, 'e', reason: 'work already in progress comes first');
      expect(cl.status, StageStatus.blocked);
      expect(cl.isComplete, isFalse);
    });

    test('the checklist is complete only when every applicable stage is', () {
      final cl = ProjectChecklist(
        id: 'c', projectId: 'p', templateId: 't', templateName: 'T', category: ServiceCategory.crm, createdAt: DateTime.now(),
        stages: [stage('one', [item('a', done)]), stage('two', [item('b', done), item('c', todo, req: false)])],
      );
      expect(cl.isComplete, isTrue);
      expect(cl.progress, 1);
      expect(cl.nextAction, isNull);
      expect(cl.currentStage, isNull);
    });

    test('overdue only applies to unfinished items', () {
      final past = DateTime.now().subtract(const Duration(days: 3));
      expect(item('a', todo).copyWith(dueDate: past).isOverdue, isTrue);
      expect(item('a', done).copyWith(dueDate: past).isOverdue, isFalse);
      expect(item('a', ChecklistItemStatus.notApplicable).copyWith(dueDate: past).isOverdue, isFalse);
    });
  });

  group('snapshots', () {
    test('a project checklist is an independent deep copy of the template', () {
      final tpl = MockChecklistTemplates.staticWebsite();
      final cl = ProjectChecklist.fromTemplate(tpl, projectId: 'p', startDate: DateTime(2026, 1, 1));
      expect(cl.stages.length, tpl.stageCount);
      expect(cl.allItems.length, tpl.itemCount);
      expect(cl.allItems.every((i) => i.status == todo), isTrue);
      // Fresh ids: nothing is shared with the template.
      final templateIds = {for (final s in tpl.stages) s.id, for (final s in tpl.stages) ...s.items.map((i) => i.id)};
      expect(cl.stages.every((s) => !templateIds.contains(s.id)), isTrue);
      expect(cl.allItems.every((i) => !templateIds.contains(i.id)), isTrue);
      // Default due offsets become real dates.
      final first = tpl.stages.first.items.first;
      expect(cl.stages.first.items.first.dueDate, DateTime(2026, 1, 1).add(Duration(days: first.dueOffsetDays!)));
    });
  });

  group('checklist notifier', () {
    late ProviderContainer c;
    late ChecklistsNotifier n;
    setUp(() {
      c = ProviderContainer();
      n = c.read(checklistsProvider.notifier);
    });
    tearDown(() => c.dispose());

    ProjectChecklist fresh() => n.createFromTemplate(MockChecklistTemplates.staticWebsite(), projectId: 'p7');
    ChecklistItem find(String id, String title) => c.read(checklistProvider(id))!.allItems.firstWhere((i) => i.title == title);

    test('skipping requires a reason', () {
      final cl = fresh();
      final it = find(cl.id, 'Collect logo and image assets');
      expect(n.setStatus(cl.id, it.id, ChecklistItemStatus.skipped), isNotNull);
      expect(n.setStatus(cl.id, it.id, ChecklistItemStatus.skipped, skipReason: '   '), isNotNull);
      expect(find(cl.id, it.title).status, todo);

      expect(n.setStatus(cl.id, it.id, ChecklistItemStatus.skipped, skipReason: 'Client has no logo yet'), isNull);
      final after = find(cl.id, it.title);
      expect(after.status, ChecklistItemStatus.skipped);
      expect(after.skipReason, 'Client has no logo yet');
      expect(after.completedAt, isNotNull);
      expect(after.history.first.detail, 'Reason: Client has no logo yet');
    });

    test('an item that needs evidence cannot be marked done until some is added', () {
      final cl = fresh();
      final it = find(cl.id, 'Collect client requirements');
      expect(it.evidenceType, EvidenceType.note);
      expect(n.setStatus(cl.id, it.id, done), isNotNull);

      n.addEvidence(cl.id, it.id, Evidence(id: 'e1', type: EvidenceType.note, value: 'Call notes saved', addedAt: DateTime.now()));
      expect(n.setStatus(cl.id, it.id, done), isNull);
      expect(find(cl.id, it.title).completedAt, isNotNull);
    });

    test('items with no evidence requirement can be completed straight away, and reopened', () {
      final cl = fresh();
      final it = find(cl.id, 'Build homepage and shared components');
      expect(it.evidenceType, EvidenceType.none);
      expect(n.setStatus(cl.id, it.id, done), isNull);
      expect(find(cl.id, it.title).status, done);
      n.setStatus(cl.id, it.id, ChecklistItemStatus.doing);
      final reopened = find(cl.id, it.title);
      expect(reopened.completedAt, isNull, reason: 'completion date is cleared when reopened');
      expect(reopened.history.length, 2);
    });

    test('progress updates immediately, and notes, due dates and history are recorded', () {
      final cl = fresh();
      expect(c.read(checklistProvider(cl.id))!.progress, 0);
      final it = find(cl.id, 'Optimise images and page speed');
      n.setStatus(cl.id, it.id, ChecklistItemStatus.doing);
      n.addNote(cl.id, it.id, 'Use WebP');
      n.setDueDate(cl.id, it.id, DateTime(2030, 5, 5));
      final after = find(cl.id, it.title);
      expect(after.notes.single.text, 'Use WebP');
      expect(after.dueDate, DateTime(2030, 5, 5));
      expect(after.history.map((h) => h.title), containsAll(['Note added', 'Due date set to 5 May 2030']));

      final required = c.read(checklistProvider(cl.id))!.allItems.where((i) => i.isRequired && i.evidenceType == EvidenceType.none);
      for (final r in required) {
        n.setStatus(cl.id, r.id, done);
      }
      expect(c.read(checklistProvider(cl.id))!.progress, greaterThan(0));
    });

    test('editing or deleting a template never changes existing checklists', () {
      final templates = c.read(templatesProvider.notifier);
      final original = templates.byId('tpl_static')!;
      final cl = n.createFromTemplate(original, projectId: 'p7');
      final stagesBefore = cl.stages.length;
      final itemsBefore = cl.allItems.length;
      final titles = cl.allItems.map((i) => i.title).toList();

      templates.save(original.copyWith(
        name: 'Renamed',
        stages: [original.stages.first.copyWith(items: const [])],
      ));
      expect(c.read(templatesProvider).firstWhere((t) => t.id == 'tpl_static').itemCount, 0);

      var snap = c.read(checklistProvider(cl.id))!;
      expect(snap.stages.length, stagesBefore);
      expect(snap.allItems.length, itemsBefore);
      expect(snap.allItems.map((i) => i.title).toList(), titles);
      expect(snap.templateName, 'Static Website Development', reason: 'the name it was started with is kept');

      templates.remove('tpl_static');
      snap = c.read(checklistProvider(cl.id))!;
      expect(snap.allItems.length, itemsBefore);
    });

    test('duplicating a template copies it with new ids', () {
      final templates = c.read(templatesProvider.notifier);
      final copy = templates.duplicate('tpl_ecom')!;
      final source = templates.byId('tpl_ecom')!;
      expect(copy.name, 'Ecommerce / Dynamic Website (Copy)');
      expect(copy.id, isNot(source.id));
      expect(copy.stageCount, source.stageCount);
      expect(copy.itemCount, source.itemCount);
      expect(copy.stages.first.id, isNot(source.stages.first.id));
    });

    test('completing a stage and then the whole checklist is logged to the activity feed', () {
      final cl = fresh();
      void finishAll(Iterable<ChecklistItem> items) {
        for (final i in items) {
          if (i.needsEvidence) {
            n.addEvidence(cl.id, i.id, Evidence(id: 'ev_${i.id}', type: i.evidenceType, value: 'proof', addedAt: DateTime.now()));
          }
          expect(n.setStatus(cl.id, i.id, done), isNull);
        }
      }

      List<String> feed() => c.read(activityProvider).map((a) => a.title).toList();
      finishAll(c.read(checklistProvider(cl.id))!.stages.first.items);
      expect(feed(), contains('Stage completed'));
      expect(feed(), isNot(contains('Delivery checklist complete')));

      finishAll(c.read(checklistProvider(cl.id))!.allItems.where((i) => i.isRequired && !i.isResolved));
      expect(c.read(checklistProvider(cl.id))!.isComplete, isTrue);
      expect(feed(), contains('Delivery checklist complete'));
    });

    test('seeded project checklists are in believable states', () {
      final all = c.read(checklistsProvider);
      expect(all.length, 6);
      final finished = all.firstWhere((x) => x.id == 'cl_p5');
      expect(finished.isComplete, isTrue);
      expect(finished.progress, 1);
      final ecom = all.firstWhere((x) => x.id == 'cl_p1');
      expect(ecom.waitingCount, 1);
      expect(ecom.blockedStageCount, 1);
      expect(ecom.progress, inExclusiveRange(0.2, 0.8));
      final monthly = all.firstWhere((x) => x.id == 'cl_p5_m');
      expect(monthly.servicePeriod, isNotNull);
    });

    test('next month starts a fresh copy of a recurring checklist', () {
      final monthly = c.read(checklistProvider('cl_p5_m'))!;
      final next = n.startNextPeriod(monthly.id)!;
      expect(next.servicePeriod, isNot(monthly.servicePeriod));
      expect(next.progress, 0);
      expect(next.allItems.length, monthly.allItems.length);
      expect(n.startNextPeriod('cl_p1'), isNull, reason: 'only recurring checklists have periods');
    });
  });
}
