import 'enums.dart';

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.vendor = '',
    this.notes = '',
    this.receiptName,
  });

  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String vendor;
  final String notes;

  /// Name of the attached receipt file (UI-only in phase 1).
  final String? receiptName;

  Expense copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? vendor,
    String? notes,
    Object? receiptName = _unset,
  }) =>
      Expense(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        date: date ?? this.date,
        vendor: vendor ?? this.vendor,
        notes: notes ?? this.notes,
        receiptName: identical(receiptName, _unset) ? this.receiptName : receiptName as String?,
      );
}

const _unset = Object();
