import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/quotation.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../automation/automation_providers.dart';
import '../dashboard/activity_providers.dart';
import '../invoices/invoice_providers.dart';

class QuotationsNotifier extends CrudNotifier<Quotation> {
  @override
  Repository<Quotation> get repository => ref.read(quotationRepositoryProvider);
  @override
  String idOf(Quotation item) => item.id;

  String nextNumber() => nextDocNumber(state.map((q) => q.number), 'QT');

  void create(Quotation q) {
    upsert(q);
    ref.read(activityProvider.notifier).log(
          q.status == QuotationStatus.sent ? 'Quotation sent' : 'Quotation drafted',
          detail: q.number,
          kind: ActivityKind.quotation,
        );
  }

  void setStatus(String id, QuotationStatus status) {
    final q = byId(id);
    if (q == null) return;
    upsert(q.copyWith(status: status));
    final feed = ref.read(activityProvider.notifier);
    switch (status) {
      case QuotationStatus.sent:
        feed.log('Quotation sent', detail: q.number, kind: ActivityKind.quotation);
      case QuotationStatus.accepted:
        feed.log('Quotation accepted', detail: q.number, kind: ActivityKind.quotation);
        if (ref.read(automationProvider.notifier).isEnabled(AutomationKind.quotation)) {
          feed.log('Automation: project draft ready', detail: 'Prepared from ${q.number}', kind: ActivityKind.automation);
        }
      default:
        break;
    }
  }
}

final quotationsProvider = NotifierProvider<QuotationsNotifier, List<Quotation>>(QuotationsNotifier.new);

final quotationProvider = Provider.family<Quotation?, String>((ref, id) {
  for (final q in ref.watch(quotationsProvider)) {
    if (q.id == id) return q;
  }
  return null;
});

final clientQuotationsProvider = Provider.family<List<Quotation>, String>(
  (ref, clientId) => ref.watch(quotationsProvider).where((q) => q.clientId == clientId).toList(),
);
