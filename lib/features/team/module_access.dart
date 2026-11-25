import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../data/models/modules.dart';
import '../../data/models/team.dart';
import 'team_providers.dart';

/// Whether the person using the app may use [module]. The database enforces the same switches,
/// so this only decides what to show.
final canUseProvider = Provider.family<bool, AppModule>((ref, module) {
  final me = ref.watch(currentMemberProvider);
  // No member loaded (briefly, while signing in): show everything and let the database decide.
  return me == null || me.canUse(module);
});

final isFounderProvider = Provider<bool>((ref) => ref.watch(currentMemberProvider)?.role == TeamRole.founder);

/// Which module a page belongs to, or null for pages everyone may open (home, more, settings, ...).
AppModule? moduleForPath(String path) {
  bool under(String root) => path == root || path.startsWith('$root/');
  if (under(Routes.leads)) return AppModule.leads;
  if (under(Routes.clients)) return AppModule.clients;
  if (under(Routes.projects)) return AppModule.projects;
  if (under(Routes.tasks)) return AppModule.tasks;
  if (under(Routes.checklists)) return AppModule.checklists;
  if (under(Routes.quotations)) return AppModule.quotations;
  if (under(Routes.invoices) || under(Routes.payments)) return AppModule.invoices;
  if (under(Routes.expenses)) return AppModule.expenses;
  if (under(Routes.support)) return AppModule.support;
  if (under(Routes.automation)) return AppModule.automation;
  if (under(Routes.reports)) return AppModule.reports;
  return null;
}

/// True for pages that only create or change things: "/leads/new", "/leads/quick" and the edit page of a record.
bool isEditingPath(String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return false;
  return parts[1] == 'new' || parts[1] == 'quick' || parts.last == 'edit' || parts.last == 'payment';
}

/// Decides whether [path] may be opened, given which modules this person has.
///
/// A module that is switched off is closed, with one exception: where work can be assigned to a person
/// (leads, tasks, tickets) they may still look at what is assigned to them, but not create or change anything.
/// The Team screens for adding and editing people are for the founder only.
bool pathAllowed(String path, {required bool Function(AppModule) canUse, required bool isFounder}) {
  if ((path == Routes.teamNew || (path.startsWith('${Routes.team}/') && path.endsWith('/edit'))) && !isFounder) return false;

  // The Finance tab is open to anyone who has at least one of the money modules.
  if (path == Routes.finance || path.startsWith('${Routes.finance}/')) {
    return canUse(AppModule.invoices) || canUse(AppModule.quotations) || canUse(AppModule.expenses);
  }

  final module = moduleForPath(path);
  if (module == null || canUse(module)) return true;
  return module.hasAssignedItems && !isEditingPath(path);
}
