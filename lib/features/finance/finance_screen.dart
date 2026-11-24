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
import '../expenses/expense_providers.dart';
import '../invoices/invoice_providers.dart';
import '../invoices/widgets/invoice_tile.dart';
import '../reports/report_providers.dart';

/// Finance tab: a quick read on money in, money owed and what to chase.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue = ref.watch(monthlyRevenueProvider);
    final expenses = ref.watch(monthlyExpensesProvider);
    final profit = revenue - expenses;
    final outstanding = ref.watch(outstandingInvoicesProvider);
    final overdue = outstanding.where((i) => i.displayStatus == InvoiceStatus.overdue).toList();
    final chase = [...overdue, ...outstanding.where((i) => i.displayStatus != InvoiceStatus.overdue)].take(3).toList();
    final payments = ref.watch(allPaymentsProvider).take(3).toList();
    final trend = ref.watch(monthlyFinanceProvider(6));

    return PageScaffold(
      title: 'Finance',
      subtitle: Fmt.monthYear(DateTime.now()),
      large: true,
      onRefresh: () => mockRefresh(context),
      actions: [
        IconButton.filled(
          tooltip: 'New invoice',
          onPressed: () => context.push(Routes.invoiceNew()),
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
        ),
      ],
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Revenue this month', value: ref.money(revenue, compact: true), color: AppColors.success),
            MetricCard(label: 'Expenses this month', value: ref.money(expenses, compact: true), color: AppColors.danger),
            MetricCard(
              label: 'Profit this month',
              value: ref.money(profit, compact: true),
              captionColor: profit >= 0 ? AppColors.success : AppColors.danger,
              caption: profit >= 0 ? 'In the green' : 'Spending more than earning',
            ),
            MetricCard(
              label: 'Outstanding',
              value: ref.money(ref.watch(outstandingTotalProvider), compact: true),
              caption: overdue.isEmpty ? '${outstanding.length} unpaid' : '${overdue.length} overdue',
              captionColor: overdue.isEmpty ? null : AppColors.danger,
              onTap: () => context.push(Routes.invoices),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ChartCard(
          title: 'Cash flow',
          subtitle: 'Revenue vs expenses, last 6 months',
          legend: const [(label: 'Revenue', color: AppColors.primary, value: null), (label: 'Expenses', color: AppColors.secondary, value: null)],
          child: AppBarChart(
            labels: [for (final m in trend) m.label],
            format: (v) => ref.money(v, compact: true),
            series: [
              ChartSeries(label: 'Revenue', color: AppColors.primary, values: [for (final m in trend) m.revenue]),
              ChartSeries(label: 'Expenses', color: AppColors.secondary, values: [for (final m in trend) m.expenses]),
            ],
          ),
        ),
        SectionHeader(title: 'To collect', actionLabel: 'All invoices', onAction: () => context.push(Routes.invoices)),
        if (chase.isEmpty)
          const AppCard(child: EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Nothing outstanding', message: 'Every sent invoice has been paid.', compact: true))
        else
          for (final i in chase) InvoiceTile(invoice: i),
        SectionHeader(title: 'Recent payments', actionLabel: 'See all', onAction: () => context.push(Routes.payments)),
        if (payments.isEmpty)
          const AppCard(child: EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No payments yet', compact: true))
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < payments.length; i++) ...[
                  InkWell(
                    onTap: () => context.push(Routes.invoice(payments[i].invoice.id)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ref.watch(clientNameProvider(payments[i].invoice.clientId)), style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                                Text('${payments[i].invoice.number}  ·  ${Fmt.date(payments[i].payment.date)}', style: AppText.caption),
                              ],
                            ),
                          ),
                          Text('+ ${ref.money(payments[i].payment.amount)}', style: AppText.bodyStrong.copyWith(color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                  if (i != payments.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        SectionHeader(title: 'Browse'),
        Row(
          children: [
            Expanded(child: AppButton.secondary(label: 'Invoices', onPressed: () => context.push(Routes.invoices))),
            const SizedBox(width: 12),
            Expanded(child: AppButton.secondary(label: 'Payments', onPressed: () => context.push(Routes.payments))),
          ],
        ),
      ],
    );
  }
}
