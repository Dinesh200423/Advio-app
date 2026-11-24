import 'package:uuid/uuid.dart';

import 'enums.dart';

const _uuid = Uuid();

/// A new record id. Generated on the device so records can be created offline and shared safely:
/// a UUID cannot collide between two people creating records at the same moment.
String newId([String prefix = 'id']) => '${prefix}_${_uuid.v4()}';

class Note {
  const Note({required this.id, required this.text, required this.at});
  final String id;
  final String text;
  final DateTime at;
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.title,
    required this.at,
    this.detail,
    this.kind = ActivityKind.note,
  });

  final String id;
  final String title;
  final String? detail;
  final DateTime at;
  final ActivityKind kind;

  factory ActivityEntry.now(String title, {String? detail, ActivityKind kind = ActivityKind.note}) =>
      ActivityEntry(id: newId('act'), title: title, detail: detail, at: DateTime.now(), kind: kind);
}

/// One row of a quotation or invoice.
class LineItem {
  const LineItem({required this.id, required this.description, this.quantity = 1, this.unitPrice = 0});
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;

  LineItem copyWith({String? description, double? quantity, double? unitPrice}) => LineItem(
        id: id,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

/// Subtotal / discount / tax / total breakdown shared by quotations and invoices.
class DocTotals {
  const DocTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double tax;
  final double total;

  factory DocTotals.compute(List<LineItem> items, {double discountPercent = 0, double taxPercent = 0}) {
    final subtotal = items.fold<double>(0, (s, i) => s + i.total);
    final discount = subtotal * discountPercent / 100;
    final taxable = subtotal - discount;
    final tax = taxable * taxPercent / 100;
    return DocTotals(subtotal: subtotal, discount: discount, tax: tax, total: taxable + tax);
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.kind,
    this.read = false,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;
  final ActivityKind kind;
  final bool read;
  final String? route;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        at: at,
        kind: kind,
        read: read ?? this.read,
        route: route,
      );
}
