import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/client.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';
import '../invoices/invoice_providers.dart';

class ClientsNotifier extends CrudNotifier<Client> {
  @override
  Repository<Client> get repository => ref.read(clientRepositoryProvider);
  @override
  String idOf(Client item) => item.id;

  void create(Client client) {
    upsert(client.copyWith(history: [ActivityEntry.now('Client added', kind: ActivityKind.client)]));
    ref.read(activityProvider.notifier).log('New client added', detail: client.displayName, kind: ActivityKind.client);
  }

  void addNote(String id, String text) => modify(
        id,
        (c) => c.copyWith(
          notes: [Note(id: newId('note'), text: text, at: DateTime.now()), ...c.notes],
          history: [ActivityEntry.now('Note added', detail: text, kind: ActivityKind.note), ...c.history],
        ),
      );
}

final clientsProvider = NotifierProvider<ClientsNotifier, List<Client>>(ClientsNotifier.new);

final clientProvider = Provider.family<Client?, String>((ref, id) {
  for (final c in ref.watch(clientsProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

/// Name lookup used by list items across features.
final clientNameProvider = Provider.family<String, String>((ref, id) => ref.watch(clientProvider(id))?.displayName ?? 'Unknown client');

/// Payments received from a client, newest first.
final clientPaymentsProvider = Provider.family<List<Payment>, String>((ref, clientId) {
  final invoices = ref.watch(invoicesProvider).where((i) => i.clientId == clientId);
  return [for (final i in invoices) ...i.payments]..sort((a, b) => b.date.compareTo(a.date));
});

/// Total billed lifetime value for a client (excludes drafts and void).
final clientLifetimeValueProvider = Provider.family<double, String>((ref, clientId) {
  return ref
      .watch(invoicesProvider)
      .where((i) => i.clientId == clientId && i.status != InvoiceStatus.draft && i.status != InvoiceStatus.voided)
      .fold<double>(0, (s, i) => s + i.paid);
});
