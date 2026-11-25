import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../clients/client_providers.dart';
import 'invoice_providers.dart';
import 'widgets/invoice_tile.dart';

/// Invoice dashboard: receivables summary above a searchable, filterable list.
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key, this.initialStatus});
  final InvoiceStatus? initialStatus;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _query = '';
  late InvoiceStatus? _status = widget.initialStatus;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(invoicesProvider);
    final q = _query.trim().toLowerCase();

    final list = all.where((i) {
      if (_status != null && i.displayStatus != _status) return false;
      if (q.isEmpty) return true;
      return i.number.toLowerCase().contains(q) || ref.read(clientNameProvider(i.clientId)).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.issueDate.compareTo(a.issueDate));

    final outstanding = ref.watch(outstandingInvoicesProvider);
    final overdue = outstanding.where((i) => i.displayStatus == InvoiceStatus.overdue).length;
    final drafts = all.where((i) => i.displayStatus == InvoiceStatus.draft).length;
    final filtering = q.isNotEmpty || _status != null;

    return PageScaffold(
      title: 'Invoices',
      onRefresh: () => pullToRefresh(context),
      actions: [
        TextButton(onPressed: () => context.push(Routes.payments), child: const Text('Payments')),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.invoiceNew()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New invoice'),
      ),
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Outstanding', value: ref.money(ref.watch(outstandingTotalProvider), compact: true), caption: '${outstanding.length} unpaid'),
            MetricCard(
              label: 'Overdue',
              value: ref.money(ref.watch(overdueTotalProvider), compact: true),
              caption: overdue == 0 ? 'Nothing late' : '$overdue late',
              captionColor: overdue == 0 ? AppColors.success : AppColors.danger,
              color: AppColors.danger,
              onTap: overdue == 0 ? null : () => setState(() => _status = InvoiceStatus.overdue),
            ),
            MetricCard(label: 'Received this month', value: ref.money(ref.watch(monthlyRevenueProvider), compact: true), color: AppColors.success),
            MetricCard(label: 'Drafts', value: '$drafts', caption: drafts == 0 ? 'None pending' : 'Not sent yet', color: AppColors.muted),
          ],
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search by client or invoice number', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<InvoiceStatus>(
          options: InvoiceStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          countOf: (s) => s == null ? all.length : all.where((i) => i.displayStatus == s).length,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: filtering ? 'No invoices match' : 'No invoices yet',
            message: filtering ? 'Try another status or search term.' : 'Create an invoice to start getting paid.',
            actionLabel: filtering ? 'Clear filters' : 'New invoice',
            onAction: filtering
                ? () => setState(() {
                      _query = '';
                      _status = null;
                    })
                : () => context.push(Routes.invoiceNew()),
          )
        else
          for (final i in list) InvoiceTile(invoice: i),
      ],
    );
  }
}
