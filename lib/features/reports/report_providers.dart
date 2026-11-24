import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../expenses/expense_providers.dart';
import '../invoices/invoice_providers.dart';

class MonthPoint {
  const MonthPoint({required this.month, required this.revenue, required this.expenses});
  final DateTime month;
  final double revenue;
  final double expenses;
  double get profit => revenue - expenses;
  String get label => Fmt.month(month);
}

/// Revenue (payments received) vs expenses for the last [months] calendar months, oldest first.
final monthlyFinanceProvider = Provider.family<List<MonthPoint>, int>((ref, months) {
  final payments = ref.watch(allPaymentsProvider);
  final expenses = ref.watch(expensesProvider);
  final now = DateTime.now();

  return [
    for (var i = months - 1; i >= 0; i--)
      () {
        final m = DateTime(now.year, now.month - i);
        return MonthPoint(
          month: m,
          revenue: payments.where((r) => isSameMonth(r.payment.date, m)).fold(0.0, (s, r) => s + r.payment.amount),
          expenses: expenses.where((e) => isSameMonth(e.date, m)).fold(0.0, (s, e) => s + e.amount),
        );
      }(),
  ];
});
