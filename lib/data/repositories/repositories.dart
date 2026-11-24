import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/backend_config.dart';
import '../backend/row_codecs.dart';
import '../backend/row_gateway.dart';
import '../backend/supabase_repository.dart';
import '../mock/mock_business.dart';
import '../mock/mock_checklist_templates.dart';
import '../mock/mock_checklists.dart';
import '../mock/mock_crm.dart';
import '../mock/mock_team.dart';
import '../models/automation_rule.dart';
import '../models/checklist.dart';
import '../models/client.dart';
import '../models/common.dart';
import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/lead.dart';
import '../models/project.dart';
import '../models/quotation.dart';
import '../models/support.dart';
import '../models/task.dart';
import '../models/team.dart';
import 'repository.dart';

// Repository providers.
//
// With Supabase configured (see BackendConfig) every provider returns a database-backed repository.
// Without it, the app runs on the built-in sample data. Screens cannot tell the difference.

final rowGatewayProvider = Provider<RowGateway>((ref) => SupabaseGateway(Supabase.instance.client));

Repository<T> _repository<T>(Ref ref, RowCodec<T> codec, List<T> Function() sample) {
  return BackendConfig.isConfigured ? SupabaseRepository<T>(ref.watch(rowGatewayProvider), codec) : MockRepository<T>(sample(), codec.idOf);
}

final leadRepositoryProvider = Provider<Repository<Lead>>((ref) => _repository(ref, Codecs.lead, MockCrm.leads));
final clientRepositoryProvider = Provider<Repository<Client>>((ref) => _repository(ref, Codecs.client, MockCrm.clients));
final projectRepositoryProvider = Provider<Repository<Project>>((ref) => _repository(ref, Codecs.project, MockCrm.projects));
final taskRepositoryProvider = Provider<Repository<Task>>((ref) => _repository(ref, Codecs.task, MockCrm.tasks));
final quotationRepositoryProvider = Provider<Repository<Quotation>>((ref) => _repository(ref, Codecs.quotation, MockBusiness.quotations));
final invoiceRepositoryProvider = Provider<Repository<Invoice>>((ref) => _repository(ref, Codecs.invoice, MockBusiness.invoices));
final expenseRepositoryProvider = Provider<Repository<Expense>>((ref) => _repository(ref, Codecs.expense, MockBusiness.expenses));
final ticketRepositoryProvider = Provider<Repository<Ticket>>((ref) => _repository(ref, Codecs.ticket, MockBusiness.tickets));
final maintenanceRepositoryProvider = Provider<Repository<MaintenancePlan>>((ref) => _repository(ref, Codecs.maintenancePlan, MockBusiness.plans));
final automationRepositoryProvider = Provider<Repository<AutomationRule>>((ref) => _repository(ref, Codecs.automationRule, MockBusiness.automations));
final activityRepositoryProvider = Provider<Repository<ActivityEntry>>((ref) => _repository(ref, Codecs.activity, MockBusiness.activity));
final checklistTemplateRepositoryProvider =
    Provider<Repository<ChecklistTemplate>>((ref) => _repository(ref, Codecs.checklistTemplate, MockChecklistTemplates.all));
final projectChecklistRepositoryProvider =
    Provider<Repository<ProjectChecklist>>((ref) => _repository(ref, Codecs.projectChecklist, MockChecklists.all));
final teamRepositoryProvider = Provider<Repository<TeamMember>>((ref) => _repository(ref, Codecs.team, MockTeam.members));
final notificationRepositoryProvider = Provider<Repository<AppNotification>>((ref) => _repository(ref, Codecs.notification, MockBusiness.notifications));

/// Every database-backed repository, so they can all be loaded after sign-in. Empty when running on sample data.
final backendRepositoriesProvider = Provider<List<SupabaseRepository<dynamic>>>((ref) {
  final all = <Object>[
    ref.watch(teamRepositoryProvider),
    ref.watch(clientRepositoryProvider),
    ref.watch(leadRepositoryProvider),
    ref.watch(projectRepositoryProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(checklistTemplateRepositoryProvider),
    ref.watch(projectChecklistRepositoryProvider),
    ref.watch(quotationRepositoryProvider),
    ref.watch(invoiceRepositoryProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(ticketRepositoryProvider),
    ref.watch(maintenanceRepositoryProvider),
    ref.watch(automationRepositoryProvider),
    ref.watch(activityRepositoryProvider),
    ref.watch(notificationRepositoryProvider),
  ];
  return all.whereType<SupabaseRepository<dynamic>>().toList();
});
