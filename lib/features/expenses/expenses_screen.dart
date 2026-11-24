import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../reports/report_providers.dart';
import 'expense_providers.dart';

enum ExpenseRange {
  thisMonth('This month'),
  lastMonth('Last month'),
  last3('3 months'),
  thisYear('This year'),
  all('All time');

  const ExpenseRange(this.label);
  final String label;

  bool contains(DateTime d) {
    final now = DateTime.now();
    return switch (this) {
      ExpenseRange.thisMonth => isSameMonth(d, now),
      ExpenseRange.lastMonth => isSameMonth(d, DateTime(now.year, now.month - 1)),
      ExpenseRange.last3 => !d.isBefore(DateTime(now.year, now.month - 2)) && !d.isAfter(now),
      ExpenseRange.thisYear => d.year == now.year,
      ExpenseRange.all => true,
    };
  }
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  ExpenseRange _range = ExpenseRange.thisMonth;
  ExpenseCategory? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(expensesProvider);
    final inRange = all.where((e) => _range.contains(e.date)).toList();
    final total = inRange.fold<double>(0, (s, e) => s + e.amount);

    final byCategory = <ExpenseCategory, double>{};
    for (final e in inRange) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final slices = (byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => ChartSlice(label: e.key.label, value: e.value, color: e.key.color))
        .toList();

    final q = _query.trim().toLowerCase();
    final list = inRange.where((e) {
      if (_category != null && e.category != _category) return false;
      return q.isEmpty || e.title.toLowerCase().contains(q) || e.vendor.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final months = ref.watch(monthlyFinanceProvider(6));

    return PageScaffold(
      title: 'Expenses',
      onRefresh: () => mockRefresh(context),
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.expenseNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      children: [
        FilterChipRow<ExpenseRange>(
          options: ExpenseRange.values,
          allLabel: null,
          selected: _range,
          labelOf: (r) => r.label,
          onSelected: (r) => setState(() {
            _range = r ?? _range;
            _category = null;
          }),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total spent', style: AppText.label),
                    const SizedBox(height: 4),
                    Text(ref.money(total), style: AppText.display.copyWith(fontSize: 28)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${inRange.length} expenses', style: AppText.labelStrong),
                  const SizedBox(height: 2),
                  Text(inRange.isEmpty ? '' : 'Avg ${ref.money(total / inRange.length, compact: true)}', style: AppText.caption),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ChartCard(
          title: 'By category',
          subtitle: _range.label,
          child: slices.isEmpty
              ? const EmptyState(icon: Icons.pie_chart_outline_rounded, title: 'No spending in this period', compact: true)
              : AppDonutChart(
                  slices: slices,
                  centerValue: ref.money(total, compact: true),
                  centerLabel: 'total',
                  valueFormat: (v) => ref.money(v, compact: true),
                ),
        ),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Monthly expenses',
          subtitle: 'Last 6 months',
          child: AppBarChart(
            height: 180,
            labels: [for (final m in months) m.label],
            format: (v) => ref.money(v, compact: true),
            series: [ChartSeries(label: 'Expenses', color: AppColors.secondary, values: [for (final m in months) m.expenses])],
          ),
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search expenses or vendors', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<ExpenseCategory>(
          options: [for (final s in slices) ExpenseCategory.values.firstWhere((c) => c.label == s.label)],
          selected: _category,
          allLabel: 'All categories',
          labelOf: (c) => c.label,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.receipt_outlined,
            title: 'No expenses found',
            message: 'Nothing recorded for this filter.',
            actionLabel: 'Add expense',
            onAction: () => context.push(Routes.expenseNew),
          )
        else
          for (final e in list) _ExpenseTile(expense: e),
      ],
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppListTile(
      onTap: () => context.push(Routes.expense(expense.id)),
      title: expense.title,
      subtitle: [if (expense.vendor.isNotEmpty) expense.vendor, Fmt.dateShort(expense.date)].join('  ·  '),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ref.money(expense.amount), style: AppText.bodyStrong),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: expense.category.color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(expense.category.label, style: AppText.caption),
          ]),
        ],
      ),
    );
  }
}
