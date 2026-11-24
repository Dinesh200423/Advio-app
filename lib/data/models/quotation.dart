import 'common.dart';
import 'enums.dart';

class Quotation {
  const Quotation({
    required this.id,
    required this.number,
    required this.clientId,
    required this.title,
    required this.items,
    required this.issueDate,
    required this.validUntil,
    this.status = QuotationStatus.draft,
    this.discountPercent = 0,
    this.taxPercent = 18,
    this.notes = '',
    this.terms = '',
  });

  final String id;
  final String number;
  final String clientId;
  final String title;
  final List<LineItem> items;
  final DateTime issueDate;
  final DateTime validUntil;
  final QuotationStatus status;
  final double discountPercent;
  final double taxPercent;
  final String notes;
  final String terms;

  DocTotals get totals => DocTotals.compute(items, discountPercent: discountPercent, taxPercent: taxPercent);

  /// A sent quotation past its validity date is shown as expired.
  QuotationStatus get displayStatus {
    final today = DateTime.now();
    final end = DateTime(validUntil.year, validUntil.month, validUntil.day, 23, 59, 59);
    if (status == QuotationStatus.sent && end.isBefore(today)) return QuotationStatus.expired;
    return status;
  }

  Quotation copyWith({
    String? clientId,
    String? title,
    List<LineItem>? items,
    DateTime? issueDate,
    DateTime? validUntil,
    QuotationStatus? status,
    double? discountPercent,
    double? taxPercent,
    String? notes,
    String? terms,
  }) =>
      Quotation(
        id: id,
        number: number,
        clientId: clientId ?? this.clientId,
        title: title ?? this.title,
        items: items ?? this.items,
        issueDate: issueDate ?? this.issueDate,
        validUntil: validUntil ?? this.validUntil,
        status: status ?? this.status,
        discountPercent: discountPercent ?? this.discountPercent,
        taxPercent: taxPercent ?? this.taxPercent,
        notes: notes ?? this.notes,
        terms: terms ?? this.terms,
      );
}
