import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/client.dart';
import '../../data/models/lead.dart';
import '../../data/models/project.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../../data/models/task.dart';
import '../automation/automation_providers.dart';
import '../clients/client_providers.dart';
import '../dashboard/activity_providers.dart';
import '../projects/project_providers.dart';
import '../team/team_providers.dart';
import '../tasks/task_providers.dart';

/// What conversion made. [projectId] is null if the project could not be saved.
class LeadConversion {
  const LeadConversion({required this.clientId, this.projectId});
  final String clientId;
  final String? projectId;
}

class LeadsNotifier extends CrudNotifier<Lead> {
  @override
  Repository<Lead> get repository => ref.read(leadRepositoryProvider);
  @override
  String idOf(Lead item) => item.id;

  ActivityNotifier get _feed => ref.read(activityProvider.notifier);

  @override
  void upsert(Lead item) {
    final before = byId(item.id);
    super.upsert(item);
    logAssignment(ref, what: 'Lead', title: item.titleLine, kind: ActivityKind.lead, from: before?.ownerId, to: item.ownerId);
  }

  void create(Lead lead) {
    upsert(lead.copyWith(history: [ActivityEntry.now('Lead created', detail: 'Source: ${lead.source.label}', kind: ActivityKind.lead)]));
    _feed.log('New lead added', detail: lead.titleLine, kind: ActivityKind.lead);

    // Automation rule: "New lead → create follow-up task".
    if (ref.read(automationProvider.notifier).isEnabled(AutomationKind.lead)) {
      final due = DateTime.now().add(const Duration(days: 1));
      ref.read(tasksProvider.notifier).upsert(Task(
            id: 'task_followup_${lead.id}',
            title: 'Follow up with ${lead.name}',
            description: 'Auto-created for new lead from ${lead.displayCompany}.',
            dueDate: DateTime(due.year, due.month, due.day, 11),
            createdAt: DateTime.now(),
            priority: Priority.medium,
            assigneeId: lead.ownerId,
          ));
      _feed.log('Automation: follow-up task created', detail: lead.name, kind: ActivityKind.automation);
    }
  }

  /// Turn a lead into a client, with a planned project carrying the requirements, and mark the lead Won.
  ///
  /// The client is saved first and waited for: if it cannot be saved the lead is left as it was and this returns null.
  /// A project that cannot be saved does not undo the client, it just comes back without a project id.
  Future<LeadConversion?> convertToClient(String leadId) async {
    final lead = byId(leadId);
    if (lead == null) return null;
    final clients = ref.read(clientsProvider.notifier);
    final projects = ref.read(projectsProvider.notifier);
    final now = DateTime.now();

    if (clients.byId(lead.convertedClientId) == null) {
      clients.create(Client(
        id: lead.convertedClientId,
        name: lead.name,
        company: lead.company,
        website: lead.website,
        address: lead.location,
        email: lead.email,
        phone: lead.phone,
        createdAt: now,
        notes: [Note(id: newId('note'), text: 'From the enquiry:\n${lead.requirementsSummary}', at: now), ...lead.notes],
      ));
    }
    await clients.flush();
    if (clients.byId(lead.convertedClientId) == null) return null;

    if (projects.byId(lead.convertedProjectId) == null) {
      projects.create(Project(
        id: lead.convertedProjectId,
        name: '${lead.displayCompany} · ${lead.service.shortLabel}',
        clientId: lead.convertedClientId,
        status: ProjectStatus.planned,
        budget: lead.estimatedValue,
        // Placeholders to edit once the plan is agreed.
        startDate: DateTime(now.year, now.month, now.day),
        endDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 30)),
        description: lead.requirementsSummary,
        ownerId: lead.ownerId,
      ));
    }
    await projects.flush();
    final hasProject = projects.byId(lead.convertedProjectId) != null;

    changeStatus(leadId, LeadStatus.won);
    modify(leadId, (l) => l.copyWith(history: [ActivityEntry.now('Converted to client', detail: lead.displayCompany, kind: ActivityKind.lead), ...l.history]));
    return LeadConversion(clientId: lead.convertedClientId, projectId: hasProject ? lead.convertedProjectId : null);
  }

  void changeStatus(String id, LeadStatus status) {
    final lead = byId(id);
    if (lead == null || lead.status == status) return;
    upsert(lead.copyWith(
      status: status,
      history: [ActivityEntry.now('Status changed to ${status.label}', kind: ActivityKind.lead), ...lead.history],
    ));
    if (status == LeadStatus.won) _feed.log('Lead won', detail: lead.titleLine, kind: ActivityKind.lead);
  }

  void addNote(String id, String text) => modify(
        id,
        (l) => l.copyWith(
          notes: [Note(id: newId('note'), text: text, at: DateTime.now()), ...l.notes],
          history: [ActivityEntry.now('Note added', detail: text, kind: ActivityKind.note), ...l.history],
        ),
      );

  void addFollowUp(String id, FollowUp followUp) => modify(
        id,
        (l) => l.copyWith(
          followUps: [...l.followUps, followUp],
          history: [
            ActivityEntry.now('${followUp.type.label} follow-up scheduled', detail: followUp.note, kind: ActivityKind.lead),
            ...l.history,
          ],
        ),
      );

  void toggleFollowUp(String id, String followUpId) => modify(id, (l) {
        final f = l.followUps.firstWhere((f) => f.id == followUpId);
        return l.copyWith(
          followUps: [for (final x in l.followUps) x.id == followUpId ? x.copyWith(done: !x.done) : x],
          history: f.done
              ? l.history
              : [ActivityEntry.now('${f.type.label} follow-up completed', detail: f.note, kind: ActivityKind.lead), ...l.history],
        );
      });
}

final leadsProvider = NotifierProvider<LeadsNotifier, List<Lead>>(LeadsNotifier.new);

/// Pending follow-ups on open leads that are due today or overdue, oldest first.
final dueFollowUpsProvider = Provider<List<({Lead lead, FollowUp followUp})>>((ref) {
  final out = <({Lead lead, FollowUp followUp})>[];
  for (final lead in ref.watch(leadsProvider)) {
    if (!lead.status.isOpen) continue;
    for (final f in lead.followUps.where((f) => !f.done && daysUntil(f.at) <= 0)) {
      out.add((lead: lead, followUp: f));
    }
  }
  out.sort((a, b) => a.followUp.at.compareTo(b.followUp.at));
  return out;
});

final leadProvider = Provider.family<Lead?, String>((ref, id) {
  for (final l in ref.watch(leadsProvider)) {
    if (l.id == id) return l;
  }
  return null;
});
