import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/support.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';
import '../team/team_providers.dart';

class TicketsNotifier extends CrudNotifier<Ticket> {
  @override
  Repository<Ticket> get repository => ref.read(ticketRepositoryProvider);
  @override
  String idOf(Ticket item) => item.id;

  String nextNumber() {
    var max = 1000;
    for (final t in state) {
      final n = int.tryParse(t.number.split('-').last);
      if (n != null && n > max) max = n;
    }
    return 'TKT-${max + 1}';
  }

  @override
  void upsert(Ticket item) {
    final before = byId(item.id);
    super.upsert(item);
    logAssignment(ref, what: 'Ticket', title: item.title, kind: ActivityKind.support, from: before?.assigneeId, to: item.assigneeId);
  }

  void create(Ticket t) {
    upsert(t.copyWith(notes: [Note(id: newId('note'), text: 'Ticket created.', at: DateTime.now())]));
    ref.read(activityProvider.notifier).log('Support ticket opened', detail: t.title, kind: ActivityKind.support);
  }

  void addNote(String id, String text) => modify(
        id,
        (t) => t.copyWith(notes: [...t.notes, Note(id: newId('note'), text: text, at: DateTime.now())]),
      );

  void setStatus(String id, TicketStatus status) {
    final t = byId(id);
    if (t == null || t.status == status) return;
    upsert(t.copyWith(
      status: status,
      notes: [...t.notes, Note(id: newId('note'), text: 'Status changed to ${status.label}.', at: DateTime.now())],
    ));
  }
}

final ticketsProvider = NotifierProvider<TicketsNotifier, List<Ticket>>(TicketsNotifier.new);

final ticketProvider = Provider.family<Ticket?, String>((ref, id) {
  for (final t in ref.watch(ticketsProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

class PlansNotifier extends CrudNotifier<MaintenancePlan> {
  @override
  Repository<MaintenancePlan> get repository => ref.read(maintenanceRepositoryProvider);
  @override
  String idOf(MaintenancePlan item) => item.id;

  void toggle(String id) => modify(id, (p) => p.copyWith(active: !p.active));
}

final plansProvider = NotifierProvider<PlansNotifier, List<MaintenancePlan>>(PlansNotifier.new);

/// Recurring monthly revenue from active maintenance plans.
final monthlyRecurringProvider =
    Provider<double>((ref) => ref.watch(plansProvider).where((p) => p.active).fold(0.0, (s, p) => s + p.monthlyFee));
