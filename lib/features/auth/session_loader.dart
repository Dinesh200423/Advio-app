import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/observability/app_log.dart';
import '../../data/backend/backend_config.dart';
import '../../data/backend/row_gateway.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
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

    _rebuildLists(ref);
    ref.read(currentMemberIdProvider.notifier).switchTo(me['id'] as String);
  } on AuthFailure {
    rethrow;
  } catch (error) {
    final mapped = mapSupabaseError(error, what: 'load session');
    throw AuthFailure(mapped.retryable ? 'Could not load your data. ${mapped.message}' : mapped.message);
  }
}

/// Every list the screens show. Each reads its repository once when built, so after the repositories
/// are reloaded they have to be rebuilt to pick up the new rows.
void _rebuildLists(Ref ref) {
  for (final provider in [
    teamProvider, clientsProvider, leadsProvider, projectsProvider, tasksProvider, templatesProvider,
    checklistsProvider, quotationsProvider, invoicesProvider, expensesProvider, ticketsProvider, plansProvider,
    automationProvider, activityProvider, notificationsProvider,
  ]) {
    ref.invalidate(provider);
  }
}

/// Read everything again from the database, so new rows from other people (or from the website form) show up.
/// Saves still on their way are allowed to finish first, so a reload never hides something just entered.
Future<void> refreshData(Ref ref) async {
  final repositories = ref.read(backendRepositoriesProvider);
  if (repositories.isEmpty) {
    // Sample data: there is nothing to fetch, so just give the pull-to-refresh its moment.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return;
  }
  await Future.wait<void>([
    for (final notifier in <CrudNotifier<dynamic>>[
      ref.read(teamProvider.notifier), ref.read(clientsProvider.notifier), ref.read(leadsProvider.notifier),
      ref.read(projectsProvider.notifier), ref.read(tasksProvider.notifier), ref.read(templatesProvider.notifier),
      ref.read(checklistsProvider.notifier), ref.read(quotationsProvider.notifier), ref.read(invoicesProvider.notifier),
      ref.read(expensesProvider.notifier), ref.read(ticketsProvider.notifier), ref.read(plansProvider.notifier),
      ref.read(automationProvider.notifier), ref.read(activityProvider.notifier), ref.read(notificationsProvider.notifier),
    ])
      notifier.flush(),
  ]);
  await Future.wait([for (final repo in repositories) repo.load()]);
  _rebuildLists(ref);
}

/// What a pull-to-refresh runs.
final dataRefreshProvider = Provider<Future<void> Function()>((ref) => () => refreshData(ref));

/// Keeps the app up to date while it is open: when anyone changes a row this person can see, the lists are
/// reloaded a moment later. Changes are batched, because one save usually touches several tables.
final liveUpdatesProvider = Provider<void>((ref) {
  if (!BackendConfig.isConfigured) return;
  final client = Supabase.instance.client;
  Timer? pending;
  final channel = client
      .channel('advio-live')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        callback: (_) {
          pending?.cancel();
          pending = Timer(const Duration(milliseconds: 1500), () {
            refreshData(ref).catchError((Object error) => AppLog.warning('Live refresh failed', error: error));
          });
        },
      )
      .subscribe();
  ref.onDispose(() {
    pending?.cancel();
    client.removeChannel(channel);
  });
});
