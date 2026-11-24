import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../checklists/checklist_providers.dart';
import '../leads/lead_providers.dart';
import '../projects/project_providers.dart';
import '../support/support_providers.dart';
import '../tasks/task_providers.dart';

/// What one person (or nobody, for the unassigned pile) currently has on their plate.
class Workload {
  const Workload({this.openTasks = 0, this.overdueTasks = 0, this.openLeads = 0, this.activeProjects = 0, this.openTickets = 0, this.checklistItems = 0});

  final int openTasks;
  final int overdueTasks;
  final int openLeads;
  final int activeProjects;
  final int openTickets;
  final int checklistItems;

  /// Rough size of the load, used to compare people.
  int get total => openTasks + openLeads + openTickets + checklistItems;
}

/// Workload for a member id; pass null for items nobody owns yet.
final workloadProvider = Provider.family<Workload, String?>((ref, memberId) {
  final tasks = ref.watch(tasksProvider).where((t) => !t.isDone && t.assigneeId == memberId);
  final leads = ref.watch(leadsProvider).where((l) => l.status.isOpen && l.ownerId == memberId);
  final projects = ref.watch(projectsProvider).where((p) => (p.status == ProjectStatus.active || p.status == ProjectStatus.planned) && p.ownerId == memberId);
  final tickets = ref.watch(ticketsProvider).where((t) => t.status.isActive && t.assigneeId == memberId);
  final items = ref.watch(checklistsProvider).expand((c) => c.allItems).where((i) => i.isApplicable && !i.isResolved && i.assigneeId == memberId);

  return Workload(
    openTasks: tasks.length,
    overdueTasks: tasks.where((t) => daysUntil(t.dueDate) < 0).length,
    openLeads: leads.length,
    activeProjects: projects.length,
    openTickets: tickets.length,
    checklistItems: items.length,
  );
});
