import 'package:intl/intl.dart';

import '../models/checklist.dart';
import '../models/common.dart';
import 'mock_checklist_templates.dart';
import 'mock_crm.dart';

/// Sample project checklists at different points in delivery.
abstract final class MockChecklists {
  static List<ProjectChecklist> all() {
    final t = MockChecklistTemplates.all();
    ChecklistTemplate tpl(String id) => t.firstWhere((x) => x.id == id);

    return [
      // Ecommerce redesign: mid-way, stuck waiting for the client on the payment gateway.
      _seed(
        id: 'cl_p1',
        template: tpl('tpl_ecom'),
        projectId: 'p1',
        doneStages: 5,
        waitingInCurrent: true,
        note: ('Finalize payment gateway', 'Aarav is checking with his accountant which gateway to use. Chased on Friday.'),
      ),
      // Booking app: in development.
      _seed(
        id: 'cl_p2',
        template: tpl('tpl_mobile'),
        projectId: 'p2',
        doneStages: 3,
        doneInCurrent: 2,
        note: ('Integrate backend APIs', 'Trainer schedule endpoint still returns timestamps in IST, need UTC.'),
      ),
      // Logistics dashboard: UAT blocked on the client.
      _seed(
        id: 'cl_p3',
        template: tpl('tpl_crm'),
        projectId: 'p3',
        doneStages: 6,
        doneInCurrent: 1,
        waitingInCurrent: true,
      ),
      // Portfolio site: close to launch.
      _seed(
        id: 'cl_p7',
        template: tpl('tpl_static'),
        projectId: 'p7',
        doneStages: 6,
        doneInCurrent: 2,
        note: ('Connect domain and hosting', 'Meera will point the DNS herself, sent her the records.'),
      ),
      // Finished project: everything signed off.
      _seed(id: 'cl_p5', template: tpl('tpl_static'), projectId: 'p5', doneStages: 10),
      // Monthly care for a live client site, current month.
      _seed(
        id: 'cl_p5_m',
        template: tpl('tpl_maint'),
        projectId: 'p5',
        doneStages: 2,
        doneInCurrent: 1,
        period: DateFormat('MMMM yyyy').format(DateTime.now()),
      ),
    ];
  }

  /// Builds a snapshot from [template] and fast-forwards it to a believable state.
  static ProjectChecklist _seed({
    required String id,
    required ChecklistTemplate template,
    required String projectId,
    required int doneStages,
    int doneInCurrent = 0,
    bool waitingInCurrent = false,
    String? period,
    (String, String)? note,
  }) {
    // Start far enough back that the next open item is due about now.
    var finished = doneInCurrent;
    for (var i = 0; i < doneStages && i < template.stages.length; i++) {
      finished += template.stages[i].items.length;
    }
    final step = template.isRecurring ? 1 : 2;
    final start = period != null ? DateTime(DateTime.now().year, DateTime.now().month, 1) : day(-(finished * step));

    final base = ProjectChecklist.fromTemplate(template, projectId: projectId, startDate: start, servicePeriod: period, createdAt: start);

    var seenOptionalSkip = false;
    final stages = <ChecklistStage>[];
    for (var si = 0; si < base.stages.length; si++) {
      final stage = base.stages[si];
      final items = <ChecklistItem>[];
      var doneHere = 0;
      var usedDoing = false;
      var usedWaiting = false;

      for (final item in stage.items) {
        final when = _finishedAt(item, start);
        if (si < doneStages) {
          if (!item.isRequired && !seenOptionalSkip && si >= 2) {
            seenOptionalSkip = true;
            items.add(item.copyWith(
              status: ChecklistItemStatus.skipped,
              skipReason: 'Client does not need this for the first release.',
              completedAt: when,
              history: [_log('Skipped: client does not need this for the first release.', when)],
            ));
          } else {
            items.add(_done(item, when));
          }
        } else if (si == doneStages) {
          if (doneHere < doneInCurrent) {
            items.add(_done(item, when));
            doneHere++;
          } else if (waitingInCurrent && item.clientDependent && !usedWaiting) {
            usedWaiting = true;
            items.add(item.copyWith(
              status: ChecklistItemStatus.waitingClient,
              history: [_log('Status changed from To Do to Waiting on Client', day(-3, 11))],
            ));
          } else if (!usedDoing && !item.clientDependent) {
            usedDoing = true;
            items.add(item.copyWith(status: ChecklistItemStatus.doing, history: [_log('Status changed from To Do to Doing', day(-1, 10))]));
          } else {
            items.add(item);
          }
        } else {
          items.add(item);
        }
      }
      stages.add(stage.copyWith(items: items));
    }

    if (note != null) {
      for (var s = 0; s < stages.length; s++) {
        final idx = stages[s].items.indexWhere((i) => i.title == note.$1);
        if (idx < 0) continue;
        final items = [...stages[s].items];
        final n = Note(id: newId('note'), text: note.$2, at: day(-2, 16));
        items[idx] = items[idx].copyWith(notes: [n], history: [_log('Note added', day(-2, 16), detail: note.$2), ...items[idx].history]);
        stages[s] = stages[s].copyWith(items: items);
      }
    }

    return ProjectChecklist(
      id: id,
      projectId: base.projectId,
      templateId: base.templateId,
      templateName: base.templateName,
      category: base.category,
      createdAt: base.createdAt,
      servicePeriod: base.servicePeriod,
      stages: stages,
    );
  }

  static DateTime _finishedAt(ChecklistItem item, DateTime start) {
    final due = item.dueDate ?? start;
    final latest = day(-1, 15);
    return due.isAfter(latest) ? latest : DateTime(due.year, due.month, due.day, 15);
  }

  static ActivityEntry _log(String title, DateTime at, {String? detail}) =>
      ActivityEntry(id: newId('hist'), title: title, detail: detail, at: at);

  static ChecklistItem _done(ChecklistItem item, DateTime at) {
    final slug = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    final evidence = switch (item.evidenceType) {
      EvidenceType.none => const <Evidence>[],
      EvidenceType.url => [Evidence(id: newId('ev'), type: EvidenceType.url, value: 'https://${slug.split('-').take(2).join('-')}.example.com', label: item.evidenceHint, addedAt: at)],
      EvidenceType.file => [Evidence(id: newId('ev'), type: EvidenceType.file, value: '$slug.pdf', label: item.evidenceHint, addedAt: at)],
      EvidenceType.note => [Evidence(id: newId('ev'), type: EvidenceType.note, value: '${item.evidenceHint.isEmpty ? item.title : item.evidenceHint}: confirmed and recorded.', label: item.evidenceHint, addedAt: at)],
    };
    return item.copyWith(
      status: ChecklistItemStatus.done,
      completedAt: at,
      evidence: evidence,
      history: [_log('Status changed from To Do to Done', at)],
    );
  }
}
