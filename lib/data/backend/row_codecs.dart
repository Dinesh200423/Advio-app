import '../models/automation_rule.dart';
import '../models/checklist.dart';
import '../models/client.dart';
import '../models/common.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/lead.dart';
import '../models/project.dart';
import '../models/quotation.dart';
import '../models/support.dart';
import '../models/task.dart';
import '../models/team.dart';

typedef Json = Map<String, dynamic>;

/// How one kind of record is stored: the table, and how to turn it into a row and back.
///
/// Rows use snake_case column names matching `supabase/migrations`. A test checks every column used
/// here against that SQL, so a typo cannot reach the live database unnoticed.
class RowCodec<T> {
  const RowCodec({required this.table, required this.idOf, required this.toRow, required this.fromRow, this.orderBy = 'updated_at', this.limit});

  final String table;
  final String Function(T) idOf;
  final Map<String, Object?> Function(T) toRow;
  final T Function(Json) fromRow;

  /// Column to sort by when loading, newest first.
  final String orderBy;

  /// Cap on how many rows are loaded (for tables that only grow, like the activity feed).
  final int? limit;

  /// For code that handles many kinds of record at once and only has an untyped codec.
  Map<String, Object?> encode(Object? item) => toRow(item as T);
  String idOfItem(Object? item) => idOf(item as T);
}

// ---------------------------------------------------------------- value helpers

String _ts(DateTime d) => d.toUtc().toIso8601String();
String? _tsOrNull(DateTime? d) => d == null ? null : _ts(d);
DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dtOrNull(Object? v) => v == null ? null : _dt(v);
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
String _str(Object? v) => (v as String?) ?? '';

/// Looks an enum up by name. Unknown names fall back instead of throwing.
T _enum<T extends Enum>(List<T> values, Object? name, T fallback) => values.asNameMap()[name] ?? fallback;
T? _enumOrNull<T extends Enum>(List<T> values, Object? name) => name == null ? null : values.asNameMap()[name];

List<T> _list<T>(Object? v, T Function(Json) fromJson) => [for (final e in (v as List? ?? const [])) fromJson(Json.from(e as Map))];

// ---------------------------------------------------------------- nested values (stored as jsonb)

Json _noteJson(Note n) => {'id': n.id, 'text': n.text, 'at': _ts(n.at)};
Note _note(Json j) => Note(id: j['id'] as String, text: _str(j['text']), at: _dt(j['at']));

Json _entryJson(ActivityEntry a) => {'id': a.id, 'title': a.title, 'detail': a.detail, 'at': _ts(a.at), 'kind': a.kind.name};
ActivityEntry _entry(Json j) => ActivityEntry(
      id: j['id'] as String,
      title: _str(j['title']),
      detail: j['detail'] as String?,
      at: _dt(j['at']),
      kind: _enum(ActivityKind.values, j['kind'], ActivityKind.note),
    );

Json _followUpJson(FollowUp f) => {'id': f.id, 'at': _ts(f.at), 'type': f.type.name, 'note': f.note, 'done': f.done};
FollowUp _followUp(Json j) => FollowUp(
      id: j['id'] as String,
      at: _dt(j['at']),
      type: _enum(FollowUpType.values, j['type'], FollowUpType.call),
      note: _str(j['note']),
      done: j['done'] as bool? ?? false,
    );

Json _milestoneJson(Milestone m) => {'id': m.id, 'title': m.title, 'dueDate': _ts(m.dueDate), 'amount': m.amount, 'done': m.done};
Milestone _milestone(Json j) => Milestone(
      id: j['id'] as String,
      title: _str(j['title']),
      dueDate: _dt(j['dueDate']),
      amount: _num(j['amount']),
      done: j['done'] as bool? ?? false,
    );

Json _fileJson(ProjectFile f) => {'id': f.id, 'name': f.name, 'sizeKb': f.sizeKb, 'addedAt': _ts(f.addedAt)};
ProjectFile _file(Json j) => ProjectFile(id: j['id'] as String, name: _str(j['name']), sizeKb: (j['sizeKb'] as num?)?.toInt() ?? 0, addedAt: _dt(j['addedAt']));

Json _lineItemJson(LineItem i) => {'id': i.id, 'description': i.description, 'quantity': i.quantity, 'unitPrice': i.unitPrice};
LineItem _lineItem(Json j) => LineItem(id: j['id'] as String, description: _str(j['description']), quantity: _num(j['quantity']), unitPrice: _num(j['unitPrice']));

Json _paymentJson(Payment p) => {
      'id': p.id,
      'invoiceId': p.invoiceId,
      'amount': p.amount,
      'date': _ts(p.date),
      'method': p.method.name,
      'reference': p.reference,
      'note': p.note,
    };
Payment _payment(Json j) => Payment(
      id: j['id'] as String,
      invoiceId: _str(j['invoiceId']),
      amount: _num(j['amount']),
      date: _dt(j['date']),
      method: _enum(PaymentMethod.values, j['method'], PaymentMethod.bankTransfer),
      reference: _str(j['reference']),
      note: _str(j['note']),
    );

Json _evidenceJson(Evidence e) => {'id': e.id, 'type': e.type.name, 'value': e.value, 'label': e.label, 'addedAt': _ts(e.addedAt)};
Evidence _evidence(Json j) => Evidence(
      id: j['id'] as String,
      type: _enum(EvidenceType.values, j['type'], EvidenceType.note),
      value: _str(j['value']),
      label: _str(j['label']),
      addedAt: _dt(j['addedAt']),
    );

Json _checklistItemJson(ChecklistItem i) => {
      'id': i.id,
      'title': i.title,
      'description': i.description,
      'isRequired': i.isRequired,
      'evidenceType': i.evidenceType.name,
      'evidenceHint': i.evidenceHint,
      'clientDependent': i.clientDependent,
      'status': i.status.name,
      'assigneeId': i.assigneeId,
      'dueDate': _tsOrNull(i.dueDate),
      'completedAt': _tsOrNull(i.completedAt),
      'skipReason': i.skipReason,
      'notes': [for (final n in i.notes) _noteJson(n)],
      'evidence': [for (final e in i.evidence) _evidenceJson(e)],
      'history': [for (final h in i.history) _entryJson(h)],
    };
ChecklistItem _checklistItem(Json j) => ChecklistItem(
      id: j['id'] as String,
      title: _str(j['title']),
      description: _str(j['description']),
      isRequired: j['isRequired'] as bool? ?? true,
      evidenceType: _enum(EvidenceType.values, j['evidenceType'], EvidenceType.none),
      evidenceHint: _str(j['evidenceHint']),
      clientDependent: j['clientDependent'] as bool? ?? false,
      status: _enum(ChecklistItemStatus.values, j['status'], ChecklistItemStatus.todo),
      assigneeId: j['assigneeId'] as String?,
      dueDate: _dtOrNull(j['dueDate']),
      completedAt: _dtOrNull(j['completedAt']),
      skipReason: j['skipReason'] as String?,
      notes: _list(j['notes'], _note),
      evidence: _list(j['evidence'], _evidence),
      history: _list(j['history'], _entry),
    );

Json _checklistStageJson(ChecklistStage s) => {
      'id': s.id,
      'name': s.name,
      'description': s.description,
      'items': [for (final i in s.items) _checklistItemJson(i)],
    };
ChecklistStage _checklistStage(Json j) =>
    ChecklistStage(id: j['id'] as String, name: _str(j['name']), description: _str(j['description']), items: _list(j['items'], _checklistItem));

Json _templateItemJson(TemplateItem i) => {
      'id': i.id,
      'title': i.title,
      'description': i.description,
      'isRequired': i.isRequired,
      'evidenceType': i.evidenceType.name,
      'evidenceHint': i.evidenceHint,
      'clientDependent': i.clientDependent,
      'dueOffsetDays': i.dueOffsetDays,
    };
TemplateItem _templateItem(Json j) => TemplateItem(
      id: j['id'] as String,
      title: _str(j['title']),
      description: _str(j['description']),
      isRequired: j['isRequired'] as bool? ?? true,
      evidenceType: _enum(EvidenceType.values, j['evidenceType'], EvidenceType.none),
      evidenceHint: _str(j['evidenceHint']),
      clientDependent: j['clientDependent'] as bool? ?? false,
      dueOffsetDays: (j['dueOffsetDays'] as num?)?.toInt(),
    );

Json _templateStageJson(TemplateStage s) => {
      'id': s.id,
      'name': s.name,
      'description': s.description,
      'items': [for (final i in s.items) _templateItemJson(i)],
    };
TemplateStage _templateStage(Json j) =>
    TemplateStage(id: j['id'] as String, name: _str(j['name']), description: _str(j['description']), items: _list(j['items'], _templateItem));

// ---------------------------------------------------------------- the records

/// One codec per table. Column names here must match `supabase/migrations/*_schema.sql`.
abstract final class Codecs {
  static final team = RowCodec<TeamMember>(
    table: 'team_members',
    idOf: (m) => m.id,
    toRow: (m) => {
      'id': m.id,
      'name': m.name,
      'role': m.role.name,
      'email': m.email,
      'phone': m.phone,
      'active': m.active,
      'joined_at': _ts(m.joinedAt),
    },
    fromRow: (r) => TeamMember(
      id: r['id'] as String,
      name: _str(r['name']),
      role: _enum(TeamRole.values, r['role'], TeamRole.developer),
      email: _str(r['email']),
      phone: _str(r['phone']),
      active: r['active'] as bool? ?? true,
      joinedAt: _dt(r['joined_at']),
    ),
  );

  static final client = RowCodec<Client>(
    table: 'clients',
    idOf: (c) => c.id,
    toRow: (c) => {
      'id': c.id,
      'name': c.name,
      'company': c.company,
      'email': c.email,
      'phone': c.phone,
      'address': c.address,
      'website': c.website,
      'status': c.status.name,
      'created_at': _ts(c.createdAt),
      'notes': [for (final n in c.notes) _noteJson(n)],
      'history': [for (final h in c.history) _entryJson(h)],
    },
    fromRow: (r) => Client(
      id: r['id'] as String,
      name: _str(r['name']),
      company: _str(r['company']),
      email: _str(r['email']),
      phone: _str(r['phone']),
      address: _str(r['address']),
      website: _str(r['website']),
      status: _enum(ClientStatus.values, r['status'], ClientStatus.active),
      createdAt: _dt(r['created_at']),
      notes: _list(r['notes'], _note),
      history: _list(r['history'], _entry),
    ),
  );

  static final lead = RowCodec<Lead>(
    table: 'leads',
    idOf: (l) => l.id,
    toRow: (l) => {
      'id': l.id,
      'name': l.name,
      'company': l.company,
      'email': l.email,
      'phone': l.phone,
      'source': l.source.name,
      'status': l.status.name,
      'service': l.service.name,
      'budget': l.budget?.name,
      'estimated_value': l.estimatedValue,
      'owner_id': l.ownerId,
      'interest': l.interest,
      'website': l.website,
      'location': l.location,
      'created_at': _ts(l.createdAt),
      'follow_ups': [for (final f in l.followUps) _followUpJson(f)],
      'notes': [for (final n in l.notes) _noteJson(n)],
      'history': [for (final h in l.history) _entryJson(h)],
    },
    fromRow: (r) => Lead(
      id: r['id'] as String,
      name: _str(r['name']),
      company: _str(r['company']),
      email: _str(r['email']),
      phone: _str(r['phone']),
      source: _enum(LeadSource.values, r['source'], LeadSource.other),
      status: _enum(LeadStatus.values, r['status'], LeadStatus.newLead),
      service: _enum(ServiceInterest.values, r['service'], ServiceInterest.other),
      budget: _enumOrNull(BudgetBand.values, r['budget']),
      estimatedValue: _num(r['estimated_value']),
      ownerId: r['owner_id'] as String?,
      interest: _str(r['interest']),
      website: _str(r['website']),
      location: _str(r['location']),
      createdAt: _dt(r['created_at']),
      followUps: _list(r['follow_ups'], _followUp),
      notes: _list(r['notes'], _note),
      history: _list(r['history'], _entry),
    ),
  );

  static final project = RowCodec<Project>(
    table: 'projects',
    idOf: (p) => p.id,
    toRow: (p) => {
      'id': p.id,
      'name': p.name,
      'client_id': p.clientId,
      'status': p.status.name,
      'budget': p.budget,
      'start_date': _ts(p.startDate),
      'end_date': _ts(p.endDate),
      'description': p.description,
      'owner_id': p.ownerId,
      'milestones': [for (final m in p.milestones) _milestoneJson(m)],
      'files': [for (final f in p.files) _fileJson(f)],
      'history': [for (final h in p.history) _entryJson(h)],
    },
    fromRow: (r) => Project(
      id: r['id'] as String,
      name: _str(r['name']),
      clientId: _str(r['client_id']),
      status: _enum(ProjectStatus.values, r['status'], ProjectStatus.planned),
      budget: _num(r['budget']),
      startDate: _dt(r['start_date']),
      endDate: _dt(r['end_date']),
      description: _str(r['description']),
      ownerId: r['owner_id'] as String?,
      milestones: _list(r['milestones'], _milestone),
      files: _list(r['files'], _file),
      history: _list(r['history'], _entry),
    ),
  );

  static final task = RowCodec<Task>(
    table: 'tasks',
    idOf: (t) => t.id,
    toRow: (t) => {
      'id': t.id,
      'title': t.title,
      'description': t.description,
      'project_id': t.projectId,
      'priority': t.priority.name,
      'status': t.status.name,
      'due_date': _ts(t.dueDate),
      'created_at': _ts(t.createdAt),
      'assignee_id': t.assigneeId,
    },
    fromRow: (r) => Task(
      id: r['id'] as String,
      title: _str(r['title']),
      description: _str(r['description']),
      projectId: r['project_id'] as String?,
      priority: _enum(Priority.values, r['priority'], Priority.medium),
      status: _enum(TaskStatus.values, r['status'], TaskStatus.todo),
      dueDate: _dt(r['due_date']),
      createdAt: _dt(r['created_at']),
      assigneeId: r['assignee_id'] as String?,
    ),
  );

  static final checklistTemplate = RowCodec<ChecklistTemplate>(
    table: 'checklist_templates',
    idOf: (t) => t.id,
    toRow: (t) => {
      'id': t.id,
      'name': t.name,
      'category': t.category.name,
      'description': t.description,
      'stages': [for (final s in t.stages) _templateStageJson(s)],
    },
    fromRow: (r) => ChecklistTemplate(
      id: r['id'] as String,
      name: _str(r['name']),
      category: _enum(ServiceCategory.values, r['category'], ServiceCategory.staticWebsite),
      description: _str(r['description']),
      updatedAt: _dt(r['updated_at']),
      stages: _list(r['stages'], _templateStage),
    ),
  );

  static final projectChecklist = RowCodec<ProjectChecklist>(
    table: 'project_checklists',
    idOf: (c) => c.id,
    toRow: (c) => {
      'id': c.id,
      'project_id': c.projectId,
      'template_id': c.templateId,
      'template_name': c.templateName,
      'category': c.category.name,
      'service_period': c.servicePeriod,
      'created_at': _ts(c.createdAt),
      'stages': [for (final s in c.stages) _checklistStageJson(s)],
    },
    fromRow: (r) => ProjectChecklist(
      id: r['id'] as String,
      projectId: _str(r['project_id']),
      templateId: _str(r['template_id']),
      templateName: _str(r['template_name']),
      category: _enum(ServiceCategory.values, r['category'], ServiceCategory.staticWebsite),
      createdAt: _dt(r['created_at']),
      servicePeriod: r['service_period'] as String?,
      stages: _list(r['stages'], _checklistStage),
    ),
  );

  static final quotation = RowCodec<Quotation>(
    table: 'quotations',
    idOf: (q) => q.id,
    toRow: (q) => {
      'id': q.id,
      'number': q.number,
      'client_id': q.clientId,
      'title': q.title,
      'items': [for (final i in q.items) _lineItemJson(i)],
      'issue_date': _ts(q.issueDate),
      'valid_until': _ts(q.validUntil),
      'status': q.status.name,
      'discount_percent': q.discountPercent,
      'tax_percent': q.taxPercent,
      'notes': q.notes,
      'terms': q.terms,
    },
    fromRow: (r) => Quotation(
      id: r['id'] as String,
      number: _str(r['number']),
      clientId: _str(r['client_id']),
      title: _str(r['title']),
      items: _list(r['items'], _lineItem),
      issueDate: _dt(r['issue_date']),
      validUntil: _dt(r['valid_until']),
      status: _enum(QuotationStatus.values, r['status'], QuotationStatus.draft),
      discountPercent: _num(r['discount_percent']),
      taxPercent: _num(r['tax_percent']),
      notes: _str(r['notes']),
      terms: _str(r['terms']),
    ),
  );

  static final invoice = RowCodec<Invoice>(
    table: 'invoices',
    idOf: (i) => i.id,
    toRow: (i) => {
      'id': i.id,
      'number': i.number,
      'client_id': i.clientId,
      'project_id': i.projectId,
      'items': [for (final l in i.items) _lineItemJson(l)],
      'issue_date': _ts(i.issueDate),
      'due_date': _ts(i.dueDate),
      'status': i.status.name,
      'discount_percent': i.discountPercent,
      'tax_percent': i.taxPercent,
      'notes': i.notes,
      'payments': [for (final p in i.payments) _paymentJson(p)],
    },
    fromRow: (r) => Invoice(
      id: r['id'] as String,
      number: _str(r['number']),
      clientId: _str(r['client_id']),
      projectId: r['project_id'] as String?,
      items: _list(r['items'], _lineItem),
      issueDate: _dt(r['issue_date']),
      dueDate: _dt(r['due_date']),
      status: _enum(InvoiceStatus.values, r['status'], InvoiceStatus.draft),
      discountPercent: _num(r['discount_percent']),
      taxPercent: _num(r['tax_percent']),
      notes: _str(r['notes']),
      payments: _list(r['payments'], _payment),
    ),
  );

  static final expense = RowCodec<Expense>(
    table: 'expenses',
    idOf: (e) => e.id,
    toRow: (e) => {
      'id': e.id,
      'title': e.title,
      'amount': e.amount,
      'category': e.category.name,
      'date': _ts(e.date),
      'vendor': e.vendor,
      'notes': e.notes,
      'receipt_name': e.receiptName,
    },
    fromRow: (r) => Expense(
      id: r['id'] as String,
      title: _str(r['title']),
      amount: _num(r['amount']),
      category: _enum(ExpenseCategory.values, r['category'], ExpenseCategory.other),
      date: _dt(r['date']),
      vendor: _str(r['vendor']),
      notes: _str(r['notes']),
      receiptName: r['receipt_name'] as String?,
    ),
  );

  static final ticket = RowCodec<Ticket>(
    table: 'tickets',
    idOf: (t) => t.id,
    toRow: (t) => {
      'id': t.id,
      'number': t.number,
      'title': t.title,
      'client_id': t.clientId,
      'description': t.description,
      'priority': t.priority.name,
      'status': t.status.name,
      'created_at': _ts(t.createdAt),
      'assignee_id': t.assigneeId,
      'notes': [for (final n in t.notes) _noteJson(n)],
    },
    fromRow: (r) => Ticket(
      id: r['id'] as String,
      number: _str(r['number']),
      title: _str(r['title']),
      clientId: _str(r['client_id']),
      description: _str(r['description']),
      priority: _enum(Priority.values, r['priority'], Priority.medium),
      status: _enum(TicketStatus.values, r['status'], TicketStatus.open),
      createdAt: _dt(r['created_at']),
      assigneeId: r['assignee_id'] as String?,
      notes: _list(r['notes'], _note),
    ),
  );

  static final maintenancePlan = RowCodec<MaintenancePlan>(
    table: 'maintenance_plans',
    idOf: (p) => p.id,
    toRow: (p) => {
      'id': p.id,
      'client_id': p.clientId,
      'name': p.name,
      'monthly_fee': p.monthlyFee,
      'next_review': _ts(p.nextReview),
      'includes': p.includes,
      'active': p.active,
    },
    fromRow: (r) => MaintenancePlan(
      id: r['id'] as String,
      clientId: _str(r['client_id']),
      name: _str(r['name']),
      monthlyFee: _num(r['monthly_fee']),
      nextReview: _dt(r['next_review']),
      includes: [for (final i in (r['includes'] as List? ?? const [])) i as String],
      active: r['active'] as bool? ?? true,
    ),
  );

  static final automationRule = RowCodec<AutomationRule>(
    table: 'automation_rules',
    idOf: (a) => a.id,
    toRow: (a) => {
      'id': a.id,
      'name': a.name,
      'trigger': a.trigger,
      'action': a.action,
      'kind': a.kind.name,
      'enabled': a.enabled,
      'runs': a.runs,
      'last_run': _tsOrNull(a.lastRun),
    },
    fromRow: (r) => AutomationRule(
      id: r['id'] as String,
      name: _str(r['name']),
      trigger: _str(r['trigger']),
      action: _str(r['action']),
      kind: _enum(AutomationKind.values, r['kind'], AutomationKind.lead),
      enabled: r['enabled'] as bool? ?? true,
      runs: (r['runs'] as num?)?.toInt() ?? 0,
      lastRun: _dtOrNull(r['last_run']),
    ),
  );

  /// The feed only ever grows, so only the most recent entries are loaded.
  static final activity = RowCodec<ActivityEntry>(
    table: 'activity',
    orderBy: 'at',
    limit: 200,
    idOf: (a) => a.id,
    toRow: (a) => {'id': a.id, 'title': a.title, 'detail': a.detail, 'at': _ts(a.at), 'kind': a.kind.name},
    fromRow: _entry,
  );

  static final notification = RowCodec<AppNotification>(
    table: 'notifications',
    orderBy: 'at',
    limit: 100,
    idOf: (n) => n.id,
    toRow: (n) => {'id': n.id, 'title': n.title, 'body': n.body, 'at': _ts(n.at), 'kind': n.kind.name, 'read': n.read, 'route': n.route},
    fromRow: (r) => AppNotification(
      id: r['id'] as String,
      title: _str(r['title']),
      body: _str(r['body']),
      at: _dt(r['at']),
      kind: _enum(ActivityKind.values, r['kind'], ActivityKind.note),
      read: r['read'] as bool? ?? false,
      route: r['route'] as String?,
    ),
  );

  static final all = <RowCodec<dynamic>>[
    team, client, lead, project, task, checklistTemplate, projectChecklist, quotation, invoice, expense, ticket, maintenancePlan, automationRule, activity, notification,
  ];
}
