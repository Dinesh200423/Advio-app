import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';

class ExpensesNotifier extends CrudNotifier<Expense> {
  @override
  Repository<Expense> get repository => ref.read(expenseRepositoryProvider);
  @override
  String idOf(Expense item) => item.id;

  void create(Expense e) {
    upsert(e);
    ref.read(activityProvider.notifier).log('Expense added', detail: e.title, kind: ActivityKind.expense);
  }
}

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

final expenseProvider = Provider.family<Expense?, String>((ref, id) {
  for (final e in ref.watch(expensesProvider)) {
    if (e.id == id) return e;
  }
  return null;
});

final monthlyExpensesProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref.watch(expensesProvider).where((e) => isSameMonth(e.date, now)).fold(0.0, (s, e) => s + e.amount);
});
