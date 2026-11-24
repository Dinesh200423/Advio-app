import 'common.dart';
import 'enums.dart';

class Payment {
  const Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.date,
    required this.method,
    this.reference = '',
    this.note = '',
  });

  final String id;
  final String invoiceId;
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final String reference;
  final String note;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.clientId,
    required this.items,
    required this.issueDate,
    required this.dueDate,
    this.projectId,
    this.status = InvoiceStatus.draft,
    this.discountPercent = 0,
    this.taxPercent = 18,
    this.notes = '',
    this.payments = const [],
  });

  final String id;
  final String number;
  final String clientId;
  final String? projectId;
  final List<LineItem> items;
  final DateTime issueDate;
  final DateTime dueDate;

  /// Lifecycle status set by the user: draft / sent / void.
  /// Paid, partially paid and overdue are derived — see [displayStatus].
  final InvoiceStatus status;
  final double discountPercent;
  final double taxPercent;
  final String notes;
  final List<Payment> payments;

  DocTotals get totals => DocTotals.compute(items, discountPercent: discountPercent, taxPercent: taxPercent);
  double get total => totals.total;
  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get balance => (total - paid).clamp(0, double.infinity).toDouble();

  bool get isPastDue {
    final today = DateTime.now();
    return DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59).isBefore(today);
  }

  InvoiceStatus get displayStatus {
    if (status == InvoiceStatus.voided) return InvoiceStatus.voided;
    if (status == InvoiceStatus.draft) return InvoiceStatus.draft;
    if (total > 0 && balance <= 0.009) return InvoiceStatus.paid;
    if (isPastDue) return InvoiceStatus.overdue;
    if (paid > 0) return InvoiceStatus.partiallyPaid;
    return InvoiceStatus.sent;
  }

  /// Counts toward receivables (sent, not void, with balance remaining).
  bool get isOutstanding =>
      status != InvoiceStatus.draft && status != InvoiceStatus.voided && balance > 0.009;

  Invoice copyWith({
    String? clientId,
    Object? projectId = _unset,
    List<LineItem>? items,
    DateTime? issueDate,
    DateTime? dueDate,
    InvoiceStatus? status,
    double? discountPercent,
    double? taxPercent,
    String? notes,
    List<Payment>? payments,
  }) =>
      Invoice(
        id: id,
        number: number,
        clientId: clientId ?? this.clientId,
        projectId: identical(projectId, _unset) ? this.projectId : projectId as String?,
        items: items ?? this.items,
        issueDate: issueDate ?? this.issueDate,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        discountPercent: discountPercent ?? this.discountPercent,
        taxPercent: taxPercent ?? this.taxPercent,
        notes: notes ?? this.notes,
        payments: payments ?? this.payments,
      );
}

const _unset = Object();
