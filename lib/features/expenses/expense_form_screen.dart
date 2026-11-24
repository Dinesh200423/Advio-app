import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import 'expense_providers.dart';
import 'widgets/receipt_picker.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  late final Expense? _existing = widget.id == null ? null : ref.read(expensesProvider.notifier).byId(widget.id);
  late final _title = TextEditingController(text: _existing?.title);
  late final _amount = TextEditingController(text: _existing == null ? '' : _existing.amount.toStringAsFixed(_existing.amount % 1 == 0 ? 0 : 2));
  late final _vendor = TextEditingController(text: _existing?.vendor);
  late final _notes = TextEditingController(text: _existing?.notes);
  late ExpenseCategory _category = _existing?.category ?? ExpenseCategory.software;
  late DateTime? _date = _existing?.date ?? DateTime.now();
  late String? _receipt = _existing?.receiptName;

  @override
  void dispose() {
    for (final c in [_title, _amount, _vendor, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Expense', fallback: Routes.expenses);
    final editing = _existing != null;

    return FormPage(
      title: editing ? 'Edit expense' : 'Add expense',
      submitLabel: editing ? 'Save changes' : 'Add expense',
      successMessage: editing ? 'Expense updated' : 'Expense added',
      onSubmit: () {
        final notifier = ref.read(expensesProvider.notifier);
        final base = _existing ??
            Expense(id: newId('exp'), title: '', amount: 0, category: _category, date: DateTime.now());
        final saved = base.copyWith(
          title: _title.text.trim(),
          amount: parseAmount(_amount.text),
          category: _category,
          date: _date,
          vendor: _vendor.text.trim(),
          notes: _notes.text.trim(),
          receiptName: _receipt,
        );
        editing ? notifier.upsert(saved) : notifier.create(saved);
        return true;
      },
      children: [
        AppTextField(controller: _title, label: 'What was it for?', required: true, hint: 'e.g. Figma subscription', textCapitalization: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Title')),
        const FormGap(),
        AppAmountField(controller: _amount, label: 'Amount', required: true, validator: (v) => Validators.amount(v)),
        const FormGap(),
        AppDropdown<ExpenseCategory>(label: 'Category', items: ExpenseCategory.values, value: _category, labelOf: (c) => c.label, onChanged: (v) => setState(() => _category = v ?? _category)),
        const FormGap(),
        AppDateField(
          label: 'Date',
          value: _date,
          required: true,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _date = d),
          validator: (v) => v == null ? 'Date is required' : (daysUntil(v) > 0 ? 'Cannot be in the future' : null),
        ),
        const FormGap(),
        AppTextField(controller: _vendor, label: 'Vendor', hint: 'Who did you pay?'),
        const FormGap(),
        AppTextField(controller: _notes, label: 'Notes', hint: 'Optional', maxLines: 3),
        const FormGap(),
        const FieldLabel('Receipt'),
        ReceiptPicker(fileName: _receipt, onChanged: (v) => setState(() => _receipt = v)),
      ],
    );
  }
}
