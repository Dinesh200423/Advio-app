import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/invoice.dart';
import '../../data/models/quotation.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';

/// Next sequential document number like `INV-2026-020`.
String nextDocNumber(Iterable<String> existing, String prefix) {
  final year = DateTime.now().year;
  var max = 0;
  for (final n in existing) {
    final tail = int.tryParse(n.split('-').last);
    if (tail != null && tail > max) max = tail;
  }
  return '$prefix-$year-${(max + 1).toString().padLeft(3, '0')}';
}

class InvoicesNotifier extends CrudNotifier<Invoice> {
  @override
  Repository<Invoice> get repository => ref.read(invoiceRepositoryProvider);
  @override
  String idOf(Invoice item) => item.id;

  String nextNumber() => nextDocNumber(state.map((i) => i.number), 'INV');

  ActivityNotifier get _feed => ref.read(activityProvider.notifier);

  void create(Invoice invoice) {
    upsert(invoice);
    _feed.log(
      invoice.status == InvoiceStatus.draft ? 'Invoice drafted' : 'Invoice ${invoice.number} sent',
      detail: invoice.number,
      kind: ActivityKind.invoice,
    );
  }

  /// Build a draft invoice from an accepted quotation.
  Invoice fromQuotation(Quotation q) {
    final invoice = Invoice(
      id: newId('inv'),
      number: nextNumber(),
      clientId: q.clientId,
      items: q.items,
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 14)),
      discountPercent: q.discountPercent,
      taxPercent: q.taxPercent,
      notes: 'Created from quotation ${q.number}',
    );
    create(invoice);
    return invoice;
  }

  void send(String id) {
    final i = byId(id);
    if (i == null || i.status != InvoiceStatus.draft) return;
    upsert(i.copyWith(status: InvoiceStatus.sent, issueDate: DateTime.now()));
    _feed.log('Invoice ${i.number} sent', kind: ActivityKind.invoice);
  }

  void voidInvoice(String id) {
    final i = byId(id);
    if (i == null) return;
    upsert(i.copyWith(status: InvoiceStatus.voided));
    _feed.log('Invoice ${i.number} voided', kind: ActivityKind.invoice);
  }

  void recordPayment(String id, Payment payment) {
    final i = byId(id);
    if (i == null) return;
    upsert(i.copyWith(
      payments: [...i.payments, payment]..sort((a, b) => b.date.compareTo(a.date)),
      status: i.status == InvoiceStatus.draft ? InvoiceStatus.sent : i.status,
    ));
    _feed.log('Payment received', detail: '${i.number} · ${payment.method.label}', kind: ActivityKind.payment);
  }

  void deletePayment(String id, String paymentId) =>
      modify(id, (i) => i.copyWith(payments: i.payments.where((p) => p.id != paymentId).toList()));
}

final invoicesProvider = NotifierProvider<InvoicesNotifier, List<Invoice>>(InvoicesNotifier.new);

final invoiceProvider = Provider.family<Invoice?, String>((ref, id) {
  for (final i in ref.watch(invoicesProvider)) {
    if (i.id == id) return i;
  }
  return null;
});

final clientInvoicesProvider = Provider.family<List<Invoice>, String>(
  (ref, clientId) => ref.watch(invoicesProvider).where((i) => i.clientId == clientId).toList(),
);

/// Invoices sent but not fully paid, most overdue first.
final outstandingInvoicesProvider = Provider<List<Invoice>>((ref) =>
    ref.watch(invoicesProvider).where((i) => i.isOutstanding).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate)));

final outstandingTotalProvider =
    Provider<double>((ref) => ref.watch(outstandingInvoicesProvider).fold(0.0, (s, i) => s + i.balance));

final overdueTotalProvider = Provider<double>((ref) => ref
    .watch(outstandingInvoicesProvider)
    .where((i) => i.displayStatus == InvoiceStatus.overdue)
    .fold(0.0, (s, i) => s + i.balance));

/// Every payment across all invoices with its invoice, newest first.
class PaymentRecord {
  const PaymentRecord(this.payment, this.invoice);
  final Payment payment;
  final Invoice invoice;
}

final allPaymentsProvider = Provider<List<PaymentRecord>>((ref) {
  final out = [
    for (final i in ref.watch(invoicesProvider))
      for (final p in i.payments) PaymentRecord(p, i),
  ]..sort((a, b) => b.payment.date.compareTo(a.payment.date));
  return out;
});

/// Money received in the current calendar month.
final monthlyRevenueProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(allPaymentsProvider)
      .where((r) => isSameMonth(r.payment.date, now))
      .fold(0.0, (s, r) => s + r.payment.amount);
});
