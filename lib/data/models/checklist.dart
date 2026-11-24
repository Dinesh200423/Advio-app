import 'common.dart';

// Delivery checklists.
//
// A ChecklistTemplate is the reusable blueprint. When a checklist is started for a
// project, the template is deep-copied into a ProjectChecklist (new ids, own
// statuses, dates, notes and evidence). Editing or deleting the template afterwards
// never touches existing project checklists.

enum ChecklistItemStatus {
  todo('To Do'),
  doing('Doing'),
  waitingClient('Waiting on Client'),
  done('Done'),
  skipped('Skipped'),
  notApplicable('Not Applicable');

  const ChecklistItemStatus(this.label);
  final String label;

  /// Counts as finished work for progress (Done, or Skipped with a reason).
  bool get isResolved => this == done || this == skipped;
}

enum StageStatus {
  notStarted('Not Started'),
  inProgress('In Progress'),
  blocked('Blocked'),
  completed('Completed');

  const StageStatus(this.label);
  final String label;
}

enum EvidenceType {
  none('No evidence required'),
  url('URL'),
  file('File'),
  note('Note');

  const EvidenceType(this.label);
  final String label;
}

enum ServiceCategory {
  staticWebsite('Static Website'),
  ecommerce('Ecommerce'),
  crm('CRM & Automation'),
  mobileApp('Mobile App'),
  workflow('Workflow Automation'),
  maintenance('Support & Maintenance');

  const ServiceCategory(this.label);
  final String label;
}

// ---------------------------------------------------------------- templates

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.title,
    this.description = '',
    this.isRequired = true,
    this.evidenceType = EvidenceType.none,
    this.evidenceHint = '',
    this.clientDependent = false,
    this.dueOffsetDays,
  });

  final String id;
  final String title;
  final String description;
  final bool isRequired;
  final EvidenceType evidenceType;

  /// What the evidence should be, e.g. "Live website URL".
  final String evidenceHint;
  final bool clientDependent;

  /// Default due date, in days after the checklist starts. Null = no due date.
  final int? dueOffsetDays;

  TemplateItem copyWith({
    String? title,
    String? description,
    bool? isRequired,
    EvidenceType? evidenceType,
    String? evidenceHint,
    bool? clientDependent,
    Object? dueOffsetDays = _unset,
  }) =>
      TemplateItem(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        isRequired: isRequired ?? this.isRequired,
        evidenceType: evidenceType ?? this.evidenceType,
        evidenceHint: evidenceHint ?? this.evidenceHint,
        clientDependent: clientDependent ?? this.clientDependent,
        dueOffsetDays: identical(dueOffsetDays, _unset) ? this.dueOffsetDays : dueOffsetDays as int?,
      );
}

class TemplateStage {
  const TemplateStage({required this.id, required this.name, this.description = '', this.items = const []});
  final String id;
  final String name;
  final String description;
  final List<TemplateItem> items;

  TemplateStage copyWith({String? name, String? description, List<TemplateItem>? items}) => TemplateStage(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        items: items ?? this.items,
      );
}

class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.updatedAt,
    this.description = '',
    this.stages = const [],
  });

  final String id;
  final String name;
  final ServiceCategory category;
  final String description;
  final List<TemplateStage> stages;
  final DateTime updatedAt;

  /// Monthly support checklists repeat every service period.
  bool get isRecurring => category == ServiceCategory.maintenance;

  int get stageCount => stages.length;
  int get itemCount => stages.fold(0, (s, st) => s + st.items.length);

  ChecklistTemplate copyWith({
    String? name,
    ServiceCategory? category,
    String? description,
    List<TemplateStage>? stages,
    DateTime? updatedAt,
  }) =>
      ChecklistTemplate(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        description: description ?? this.description,
        stages: stages ?? this.stages,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ---------------------------------------------------------- project checklist

class Evidence {
  const Evidence({required this.id, required this.type, required this.value, required this.addedAt, this.label = ''});
  final String id;

  /// Never [EvidenceType.none].
  final EvidenceType type;

  /// URL, file name or note text depending on [type].
  final String value;
  final String label;
  final DateTime addedAt;
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    this.description = '',
    this.isRequired = true,
    this.evidenceType = EvidenceType.none,
    this.evidenceHint = '',
    this.clientDependent = false,
    this.status = ChecklistItemStatus.todo,
    this.assigneeId,
    this.dueDate,
    this.completedAt,
    this.skipReason,
    this.notes = const [],
    this.evidence = const [],
    this.history = const [],
  });

  final String id;
  final String title;
  final String description;
  final bool isRequired;
  final EvidenceType evidenceType;
  final String evidenceHint;
  final bool clientDependent;
  final ChecklistItemStatus status;

  /// Team member responsible for this item; null means unassigned.
  final String? assigneeId;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? skipReason;

  /// Newest first.
  final List<Note> notes;
  final List<Evidence> evidence;

  /// Newest first.
  final List<ActivityEntry> history;

  bool get isApplicable => status != ChecklistItemStatus.notApplicable;
  bool get isResolved => status.isResolved;

  /// Evidence is required but nothing has been added yet.
  bool get needsEvidence => evidenceType != EvidenceType.none && evidence.isEmpty;

  bool get isOverdue {
    if (dueDate == null || isResolved || !isApplicable) return false;
    final d = dueDate!;
    final today = DateTime.now();
    return DateTime(d.year, d.month, d.day).isBefore(DateTime(today.year, today.month, today.day));
  }

  ChecklistItem copyWith({
    ChecklistItemStatus? status,
    Object? assigneeId = _unset,
    Object? dueDate = _unset,
    Object? completedAt = _unset,
    Object? skipReason = _unset,
    List<Note>? notes,
    List<Evidence>? evidence,
    List<ActivityEntry>? history,
  }) =>
      ChecklistItem(
        id: id,
        title: title,
        description: description,
        isRequired: isRequired,
        evidenceType: evidenceType,
        evidenceHint: evidenceHint,
        clientDependent: clientDependent,
        status: status ?? this.status,
        assigneeId: identical(assigneeId, _unset) ? this.assigneeId : assigneeId as String?,
        dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
        completedAt: identical(completedAt, _unset) ? this.completedAt : completedAt as DateTime?,
        skipReason: identical(skipReason, _unset) ? this.skipReason : skipReason as String?,
        notes: notes ?? this.notes,
        evidence: evidence ?? this.evidence,
        history: history ?? this.history,
      );
}

class ChecklistStage {
  const ChecklistStage({required this.id, required this.name, this.description = '', this.items = const []});
  final String id;
  final String name;
  final String description;
  final List<ChecklistItem> items;

  /// Items that count (Not Applicable ones are excluded everywhere).
  List<ChecklistItem> get applicable => items.where((i) => i.isApplicable).toList();

  /// Required items that are applicable.
  List<ChecklistItem> get requiredItems => applicable.where((i) => i.isRequired).toList();

  /// The items that decide progress and completion: the required ones, or, for a
  /// stage that has none, everything applicable.
  List<ChecklistItem> get _pool {
    final req = requiredItems;
    return req.isNotEmpty ? req : applicable;
  }

  /// A stage with nothing applicable is skipped over by overall progress.
  bool get isApplicable => applicable.isNotEmpty;

  int get totalCount => applicable.length;
  int get doneCount => applicable.where((i) => i.isResolved).length;
  int get requiredTotal => requiredItems.length;
  int get requiredDone => requiredItems.where((i) => i.isResolved).length;
  int get waitingCount => applicable.where((i) => i.status == ChecklistItemStatus.waitingClient).length;

  /// Share of deciding items resolved, 0..1.
  double get progress {
    final pool = _pool;
    return pool.isEmpty ? 1 : pool.where((i) => i.isResolved).length / pool.length;
  }

  bool get isComplete => _pool.every((i) => i.isResolved);

  StageStatus get status {
    if (isComplete) return StageStatus.completed;
    if (requiredItems.any((i) => i.status == ChecklistItemStatus.waitingClient)) return StageStatus.blocked;
    if (applicable.any((i) => i.status != ChecklistItemStatus.todo)) return StageStatus.inProgress;
    return StageStatus.notStarted;
  }

  ChecklistStage copyWith({List<ChecklistItem>? items}) =>
      ChecklistStage(id: id, name: name, description: description, items: items ?? this.items);
}

class ProjectChecklist {
  const ProjectChecklist({
    required this.id,
    required this.projectId,
    required this.templateId,
    required this.templateName,
    required this.category,
    required this.createdAt,
    this.servicePeriod,
    this.stages = const [],
  });

  final String id;
  final String projectId;

  /// Where the snapshot came from. The template may since have changed or been deleted.
  final String templateId;
  final String templateName;
  final ServiceCategory category;
  final DateTime createdAt;

  /// Only for recurring checklists, e.g. "November 2026".
  final String? servicePeriod;
  final List<ChecklistStage> stages;

  /// Deep copy of [template]: new ids, every item starts as To Do.
  factory ProjectChecklist.fromTemplate(
    ChecklistTemplate template, {
    required String projectId,
    required DateTime startDate,
    String? servicePeriod,
    DateTime? createdAt,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return ProjectChecklist(
      id: newId('cl'),
      projectId: projectId,
      templateId: template.id,
      templateName: template.name,
      category: template.category,
      createdAt: createdAt ?? DateTime.now(),
      servicePeriod: servicePeriod,
      stages: [
        for (final s in template.stages)
          ChecklistStage(
            id: newId('stage'),
            name: s.name,
            description: s.description,
            items: [
              for (final i in s.items)
                ChecklistItem(
                  id: newId('item'),
                  title: i.title,
                  description: i.description,
                  isRequired: i.isRequired,
                  evidenceType: i.evidenceType,
                  evidenceHint: i.evidenceHint,
                  clientDependent: i.clientDependent,
                  dueDate: i.dueOffsetDays == null ? null : start.add(Duration(days: i.dueOffsetDays!)),
                ),
            ],
          ),
      ],
    );
  }

  List<ChecklistStage> get activeStages => stages.where((s) => s.isApplicable).toList();

  Iterable<ChecklistItem> get allItems => stages.expand((s) => s.items);
  Iterable<ChecklistItem> get _applicableItems => allItems.where((i) => i.isApplicable);

  /// Required items across applicable stages.
  int get requiredTotal => activeStages.fold(0, (s, st) => s + st.requiredTotal);
  int get requiredDone => activeStages.fold(0, (s, st) => s + st.requiredDone);

  /// Overall progress, 0..1, weighted by the deciding items of each stage.
  double get progress {
    var total = 0;
    var done = 0;
    for (final s in activeStages) {
      final pool = s._pool;
      total += pool.length;
      done += pool.where((i) => i.isResolved).length;
    }
    return total == 0 ? 1 : done / total;
  }

  int get completedCount => _applicableItems.where((i) => i.isResolved).length;
  int get pendingCount => _applicableItems.where((i) => !i.isResolved).length;
  int get waitingCount => _applicableItems.where((i) => i.status == ChecklistItemStatus.waitingClient).length;
  int get overdueCount => allItems.where((i) => i.isOverdue).length;
  int get blockedStageCount => activeStages.where((s) => s.status == StageStatus.blocked).length;

  bool get isComplete => activeStages.every((s) => s.isComplete);

  /// First stage that still has work, or null when everything is done.
  ChecklistStage? get currentStage {
    for (final s in activeStages) {
      if (!s.isComplete) return s;
    }
    return null;
  }

  /// The most useful thing to do next: a required item already in progress,
  /// then one not started, then one that is waiting on the client.
  ChecklistItem? get nextAction {
    final stage = currentStage;
    if (stage == null) return null;
    final open = stage.applicable.where((i) => !i.isResolved && i.isRequired).toList();
    final pool = open.isNotEmpty ? open : stage.applicable.where((i) => !i.isResolved).toList();
    for (final status in [ChecklistItemStatus.doing, ChecklistItemStatus.todo, ChecklistItemStatus.waitingClient]) {
      for (final i in pool) {
        if (i.status == status) return i;
      }
    }
    return pool.isEmpty ? null : pool.first;
  }

  StageStatus get status {
    if (isComplete) return StageStatus.completed;
    if (blockedStageCount > 0) return StageStatus.blocked;
    if (_applicableItems.any((i) => i.status != ChecklistItemStatus.todo)) return StageStatus.inProgress;
    return StageStatus.notStarted;
  }

  ChecklistStage? stageOf(String itemId) {
    for (final s in stages) {
      if (s.items.any((i) => i.id == itemId)) return s;
    }
    return null;
  }

  ChecklistItem? item(String itemId) {
    for (final i in allItems) {
      if (i.id == itemId) return i;
    }
    return null;
  }

  ProjectChecklist copyWith({List<ChecklistStage>? stages}) => ProjectChecklist(
        id: id,
        projectId: projectId,
        templateId: templateId,
        templateName: templateName,
        category: category,
        createdAt: createdAt,
        servicePeriod: servicePeriod,
        stages: stages ?? this.stages,
      );
}

const _unset = Object();
