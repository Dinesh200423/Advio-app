import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/invoice.dart';
import '../clients/client_providers.dart';
import 'invoice_providers.dart';

/// Record a full or partial payment against an invoice.
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  late final Invoice? _invoice = ref.read(invoicesProvider.notifier).byId(widget.invoiceId);
  late final _amount = TextEditingController(text: _invoice == null ? '' : _invoice.balance.toStringAsFixed(_invoice.balance % 1 == 0 ? 0 : 2));
  final _reference = TextEditingController();
  final _note = TextEditingController();
  DateTime? _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.bankTransfer;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    if (invoice == null) return const MissingRecord(what: 'Invoice', fallback: Routes.invoices);
    final client = ref.watch(clientNameProvider(invoice.clientId));
    final entered = parseAmount(_amount.text);
    final remaining = (invoice.balance - entered).clamp(0, double.infinity).toDouble();

    return FormPage(
      title: 'Record payment',
      submitLabel: 'Save payment',
      successMessage: 'Payment recorded',
      onSubmit: () {
        ref.read(invoicesProvider.notifier).recordPayment(
              invoice.id,
              Payment(
                id: newId('pay'),
                invoiceId: invoice.id,
                amount: parseAmount(_amount.text),
                date: _date!,
                method: _method,
                reference: _reference.text.trim(),
                note: _note.text.trim(),
              ),
            );
        return true;
      },
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${invoice.number}  ·  $client', style: AppText.labelStrong),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Line(label: 'Invoice total', value: ref.money(invoice.total))),
                  Expanded(child: _Line(label: 'Already paid', value: ref.money(invoice.paid))),
                  Expanded(child: _Line(label: 'Balance due', value: ref.money(invoice.balance), color: AppColors.danger)),
                ],
              ),
            ],
          ),
        ),
        const FormGap(height: 24),
        AppAmountField(
          controller: _amount,
          label: 'Amount received',
          required: true,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final base = Validators.amount(v);
            if (base != null) return base;
            return parseAmount(v) > invoice.balance + 0.01 ? 'More than the balance due' : null;
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ActionChip(
              label: const Text('Full balance'),
              onPressed: () => setState(() => _amount.text = invoice.balance.toStringAsFixed(invoice.balance % 1 == 0 ? 0 : 2)),
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Half'),
              onPressed: () => setState(() => _amount.text = (invoice.balance / 2).round().toString()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entered > 0)
          Text(
            remaining <= 0.009 ? 'This settles the invoice in full.' : 'Partial payment: ${ref.money(remaining)} will remain outstanding.',
            style: AppText.label.copyWith(color: remaining <= 0.009 ? AppColors.success : AppColors.warning),
          ),
        const FormGap(),
        AppDateField(
          label: 'Payment date',
          value: _date,
          required: true,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _date = d),
          validator: (v) => v == null ? 'Payment date is required' : (daysUntil(v) > 0 ? 'Cannot be in the future' : null),
        ),
        const FormGap(),
        AppDropdown<PaymentMethod>(label: 'Method', items: PaymentMethod.values, value: _method, labelOf: (m) => m.label, onChanged: (v) => setState(() => _method = v ?? _method)),
        const FormGap(),
        AppTextField(controller: _reference, label: 'Reference / transaction ID', hint: 'Optional'),
        const FormGap(),
        AppTextField(controller: _note, label: 'Note', hint: 'Optional', maxLines: 2),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.bodyStrong.copyWith(color: color))),
        ],
      );
}
