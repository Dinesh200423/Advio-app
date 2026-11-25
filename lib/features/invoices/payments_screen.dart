import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../clients/client_providers.dart';
import 'invoice_providers.dart';

/// Every payment received, newest first.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  PaymentMethod? _method;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allPaymentsProvider);
    final q = _query.trim().toLowerCase();
    final list = all.where((r) {
      if (_method != null && r.payment.method != _method) return false;
      if (q.isEmpty) return true;
      return r.invoice.number.toLowerCase().contains(q) || ref.read(clientNameProvider(r.invoice.clientId)).toLowerCase().contains(q);
    }).toList();
    final total = all.fold<double>(0, (s, r) => s + r.payment.amount);

    return PageScaffold(
      title: 'Payments',
      onRefresh: () => pullToRefresh(context),
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Received this month', value: ref.money(ref.watch(monthlyRevenueProvider), compact: true), color: AppColors.success),
            MetricCard(label: 'All time', value: ref.money(total, compact: true), caption: '${all.length} payments'),
          ],
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search client or invoice', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<PaymentMethod>(
          options: PaymentMethod.values,
          selected: _method,
          labelOf: (m) => m.label,
          onSelected: (m) => setState(() => _method = m),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No payments found', message: 'Payments you record on invoices show up here.')
        else
          for (final r in list)
            AppListTile(
              onTap: () => context.push(Routes.invoice(r.invoice.id)),
              title: ref.watch(clientNameProvider(r.invoice.clientId)),
              subtitle: '${r.invoice.number}  ·  ${r.payment.method.label}  ·  ${Fmt.date(r.payment.date)}',
              trailing: Text('+ ${ref.money(r.payment.amount)}', style: AppText.bodyStrong.copyWith(color: AppColors.success)),
            ),
      ],
    );
  }
}
