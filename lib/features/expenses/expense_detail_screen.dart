import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/utils/formatters.dart';
import 'expense_providers.dart';
import 'widgets/receipt_picker.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(expenseProvider(id));
    if (e == null) return const MissingRecord(what: 'Expense', fallback: Routes.expenses);

    return PageScaffold(
      title: 'Expense',
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.expenseEdit(id)),
          deleteTitle: 'Delete expense?',
          deleteMessage: '"${e.title}" will be permanently removed.',
          onDelete: () {
            ref.read(expensesProvider.notifier).remove(id);
            context.popOr(Routes.expenses);
            AppSnack.success(context, 'Expense deleted');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.title, style: AppText.sectionTitle),
              const SizedBox(height: 12),
              Text(ref.money(e.amount), style: AppText.display),
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: e.category.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(e.category.label, style: AppText.label),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(children: [
          InfoRow(label: 'Date', value: Fmt.date(e.date)),
          InfoRow(label: 'Vendor', value: e.vendor),
          InfoRow(label: 'Notes', value: e.notes),
        ]),
        const SizedBox(height: 24),
        Text('Receipt', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        ReceiptPicker(
          fileName: e.receiptName,
          onChanged: (v) {
            ref.read(expensesProvider.notifier).upsert(e.copyWith(receiptName: v));
            AppSnack.success(context, v == null ? 'Receipt removed' : 'Receipt attached');
          },
        ),
      ],
    );
  }
}
