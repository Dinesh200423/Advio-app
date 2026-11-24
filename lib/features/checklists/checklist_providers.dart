import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/checklist.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';
import '../projects/project_providers.dart';
import '../team/team_providers.dart';

// ------------------------------------------------------------------ templates

class TemplatesNotifier extends CrudNotifier<ChecklistTemplate> {
  @override
  Repository<ChecklistTemplate> get repository => ref.read(checklistTemplateRepositoryProvider);
  @override
  String idOf(ChecklistTemplate item) => item.id;

  /// Save a new or edited template. Existing project checklists are not touched:
  /// they hold their own copy.
  void save(ChecklistTemplate template) => upsert(template.copyWith(updatedAt: DateTime.now()));

  ChecklistTemplate? duplicate(String id) {
    final source = byId(id);
    if (source == null) return null;
    final copy = ChecklistTemplate(
      id: newId('tpl'),
      name: '${source.name} (Copy)',
      category: source.category,
      description: source.description,
      updatedAt: DateTime.now(),
      stages: [
        for (final s in source.stages)
          TemplateStage(
            id: newId('ts'),
            name: s.name,
            description: s.description,
            items: [
              for (final i in s.items)
                TemplateItem(
                  id: newId('ti'),
                  title: i.title,
                  description: i.description,
                  isRequired: i.isRequired,
                  evidenceType: i.evidenceType,
                  evidenceHint: i.evidenceHint,
                  clientDependent: i.clientDependent,
                  dueOffsetDays: i.dueOffsetDays,
                ),
            ],
          ),
      ],
    );
    upsert(copy);
    return copy;
  }
}

final templatesProvider = NotifierProvider<TemplatesNotifier, List<ChecklistTemplate>>(TemplatesNotifier.new);

final templateProvider = Provider.family<ChecklistTemplate?, String>((ref, id) {
  for (final t in ref.watch(templatesProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

/// How many project checklists were started from a template.
final templateUsageProvider =
    Provider.family<int, String>((ref, id) => ref.watch(checklistsProvider).where((c) => c.templateId == id).length);

// ------------------------------------------------------------------ checklists

class ChecklistsNotifier extends CrudNotifier<ProjectChecklist> {
  @override
  Repository<ProjectChecklist> get repository => ref.read(projectChecklistRepositoryProvider);
  @override
  String idOf(ProjectChecklist item) => item.id;

  ActivityNotifier get _feed => ref.read(activityProvider.notifier);

  String _projectName(String projectId) => ref.read(projectsProvider.notifier).byId(projectId)?.name ?? 'project';

  ProjectChecklist createFromTemplate(ChecklistTemplate template, {required String projectId, String? period}) {
    final project = ref.read(projectsProvider.notifier).byId(projectId);
    final checklist = ProjectChecklist.fromTemplate(
      template,
      projectId: projectId,
      startDate: period == null ? (project?.startDate ?? DateTime.now()) : DateTime(DateTime.now().year, DateTime.now().month, 1),
      servicePeriod: period,
    );
    upsert(checklist);
    _feed.log('Checklist started', detail: '${template.name} · ${_projectName(projectId)}', kind: ActivityKind.project);
    return checklist;
  }

  /// Recurring checklists: begin the following month from the latest template
  /// (or from the previous copy if the template has been deleted).
  ProjectChecklist? startNextPeriod(String id) {
    final current = byId(id);
    if (current == null || current.servicePeriod == null) return null;
    final next = DateTime(current.createdAt.year, current.createdAt.month + 1, 1);
    final period = DateFormat('MMMM yyyy').format(next);
    final template = ref.read(templatesProvider.notifier).byId(current.templateId);

    final ProjectChecklist fresh;
    if (template != null) {
      fresh = ProjectChecklist.fromTemplate(template, projectId: current.projectId, startDate: next, servicePeriod: period, createdAt: next);
    } else {
      // Rebuild from the old copy with everything reset.
      final asTemplate = ChecklistTemplate(
        id: current.templateId,
        name: current.templateName,
        category: current.category,
        updatedAt: DateTime.now(),
        stages: [
          for (final s in current.stages)
            TemplateStage(id: s.id, name: s.name, description: s.description, items: [
              for (final i in s.items)
                TemplateItem(
                  id: i.id,
                  title: i.title,
                  description: i.description,
                  isRequired: i.isRequired,
                  evidenceType: i.evidenceType,
                  evidenceHint: i.evidenceHint,
                  clientDependent: i.clientDependent,
                  dueOffsetDays: i.dueDate?.difference(DateTime(current.createdAt.year, current.createdAt.month, current.createdAt.day)).inDays,
                ),
            ]),
        ],
      );
      fresh = ProjectChecklist.fromTemplate(asTemplate, projectId: current.projectId, startDate: next, servicePeriod: period, createdAt: next);
    }
    upsert(fresh);
    return fresh;
  }

  /// Rewrites one item and returns the updated checklist. Logs stage/checklist
  /// completion to the activity feed when this change causes it.
  void _edit(String checklistId, String itemId, ChecklistItem Function(ChecklistItem item) change) {
    final cl = byId(checklistId);
    if (cl == null) return;
    final stageBefore = cl.stageOf(itemId);
    final stageWasComplete = stageBefore?.isComplete ?? false;
    final checklistWasComplete = cl.isComplete;

    final updated = cl.copyWith(stages: [
      for (final s in cl.stages)
        s.items.any((i) => i.id == itemId)
            ? s.copyWith(items: [for (final i in s.items) i.id == itemId ? change(i) : i])
            : s,
    ]);
    upsert(updated);

    final stageNow = updated.stageOf(itemId);
    final name = _projectName(cl.projectId);
    if (stageNow != null && !stageWasComplete && stageNow.isComplete) {
      _feed.log('Stage completed', detail: '${stageNow.name} · $name', kind: ActivityKind.project);
    }
    if (!checklistWasComplete && updated.isComplete) {
      _feed.log('Delivery checklist complete', detail: '${cl.templateName} · $name', kind: ActivityKind.project);
    }
  }

  ActivityEntry _entry(String title, {String? detail}) => ActivityEntry.now(title, detail: detail);

  /// Change an item's status. Returns an error message when the change is not
  /// allowed (the UI should have asked for the missing piece first), else null.
  String? setStatus(String checklistId, String itemId, ChecklistItemStatus status, {String? skipReason}) {
    final item = byId(checklistId)?.item(itemId);
    if (item == null) return 'Item not found';
    if (item.status == status) return null;

    final reason = skipReason?.trim() ?? '';
    if (status == ChecklistItemStatus.skipped && reason.isEmpty) return 'A reason is required to skip an item';
    if (status == ChecklistItemStatus.done && item.needsEvidence) return 'Add evidence before marking this item done';

    _edit(checklistId, itemId, (i) {
      final isSkip = status == ChecklistItemStatus.skipped;
      final isDone = status == ChecklistItemStatus.done;
      return i.copyWith(
        status: status,
        completedAt: (isDone || isSkip) ? DateTime.now() : null,
        skipReason: isSkip ? reason : null,
        history: [
          _entry('Status changed from ${i.status.label} to ${status.label}', detail: isSkip ? 'Reason: $reason' : null),
          ...i.history,
        ],
      );
    });
    return null;
  }

  void setAssignee(String checklistId, String itemId, String? memberId) {
    final item = byId(checklistId)?.item(itemId);
    if (item == null || item.assigneeId == memberId) return;
    final who = memberId == null ? 'Unassigned' : 'Assigned to ${ref.read(teamProvider.notifier).byId(memberId)?.name ?? 'a teammate'}';
    _edit(checklistId, itemId, (i) => i.copyWith(assigneeId: memberId, history: [_entry(who), ...i.history]));
    logAssignment(ref, what: 'Checklist item', title: item.title, kind: ActivityKind.project, from: item.assigneeId, to: memberId);
  }

  void setDueDate(String checklistId, String itemId, DateTime? date) => _edit(
        checklistId,
        itemId,
        (i) => i.copyWith(
          dueDate: date,
          history: [
            _entry(date == null ? 'Due date removed' : 'Due date set to ${DateFormat('d MMM yyyy').format(date)}'),
            ...i.history,
          ],
        ),
      );

  void addNote(String checklistId, String itemId, String text) => _edit(
        checklistId,
        itemId,
        (i) => i.copyWith(
          notes: [Note(id: newId('note'), text: text, at: DateTime.now()), ...i.notes],
          history: [_entry('Note added', detail: text), ...i.history],
        ),
      );

  void addEvidence(String checklistId, String itemId, Evidence evidence) => _edit(
        checklistId,
        itemId,
        (i) => i.copyWith(
          evidence: [evidence, ...i.evidence],
          history: [_entry('${evidence.type.label} evidence added', detail: evidence.value), ...i.history],
        ),
      );

  void removeEvidence(String checklistId, String itemId, String evidenceId) => _edit(
        checklistId,
        itemId,
        (i) => i.copyWith(
          evidence: i.evidence.where((e) => e.id != evidenceId).toList(),
          history: [_entry('Evidence removed'), ...i.history],
        ),
      );
}

final checklistsProvider = NotifierProvider<ChecklistsNotifier, List<ProjectChecklist>>(ChecklistsNotifier.new);

final checklistProvider = Provider.family<ProjectChecklist?, String>((ref, id) {
  for (final c in ref.watch(checklistsProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

final projectChecklistsProvider = Provider.family<List<ProjectChecklist>, String>(
  (ref, projectId) => ref.watch(checklistsProvider).where((c) => c.projectId == projectId).toList(),
);
