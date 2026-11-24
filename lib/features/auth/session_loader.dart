import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/backend/row_gateway.dart';
import '../../data/repositories/repositories.dart';
import '../automation/automation_providers.dart';
import '../checklists/checklist_providers.dart';
import '../clients/client_providers.dart';
import '../dashboard/activity_providers.dart';
import '../expenses/expense_providers.dart';
import '../invoices/invoice_providers.dart';
import '../leads/lead_providers.dart';
import '../projects/project_providers.dart';
import '../quotations/quotation_providers.dart';
import '../support/support_providers.dart';
import '../tasks/task_providers.dart';
import '../team/team_providers.dart';
import 'auth_providers.dart';

/// After signing in: find out who this is, load everything they are allowed to see, and make the app
/// act as them. Throws [AuthFailure] with a message for the person if that is not possible.
Future<void> loadSession(Ref ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw const AuthFailure('Please sign in again.');

  try {
    // Row Level Security only lets a login see its own team member once it is linked and active.
    final me = await client.from('team_members').select('id').eq('user_id', userId).eq('active', true).maybeSingle();
    if (me == null) {
      throw const AuthFailure('Your login is not linked to a team member yet. Ask the ADVIO founder to add you.');
    }

    await Future.wait([for (final repo in ref.read(backendRepositoriesProvider)) repo.load()]);

    // Notifiers read their repository once when first built; make sure none was built before the data arrived.
    for (final provider in [
      teamProvider, clientsProvider, leadsProvider, projectsProvider, tasksProvider, templatesProvider,
      checklistsProvider, quotationsProvider, invoicesProvider, expensesProvider, ticketsProvider, plansProvider,
      automationProvider, activityProvider, notificationsProvider,
    ]) {
      ref.invalidate(provider);
    }
    ref.read(currentMemberIdProvider.notifier).switchTo(me['id'] as String);
  } on AuthFailure {
    rethrow;
  } catch (error) {
    final mapped = mapSupabaseError(error, what: 'load session');
    throw AuthFailure(mapped.retryable ? 'Could not load your data. ${mapped.message}' : mapped.message);
  }
}
