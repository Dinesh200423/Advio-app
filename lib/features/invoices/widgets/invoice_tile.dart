import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/invoice.dart';
import '../../clients/client_providers.dart';

class InvoiceTile extends ConsumerWidget {
  const InvoiceTile({super.key, required this.invoice, this.margin = const EdgeInsets.only(bottom: 12), this.showClient = true});
  final Invoice invoice;
  final EdgeInsetsGeometry margin;
  final bool showClient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = invoice.displayStatus;
    final client = showClient ? ref.watch(clientNameProvider(invoice.clientId)) : null;
    final overdue = status == InvoiceStatus.overdue;
    final settled = status == InvoiceStatus.paid || status == InvoiceStatus.voided || status == InvoiceStatus.draft;

    final dueText = switch (status) {
      InvoiceStatus.paid => 'Paid in full',
      InvoiceStatus.draft => 'Not sent yet',
      InvoiceStatus.voided => 'Void',
      _ => overdue ? '${-daysUntil(invoice.dueDate)} days overdue' : 'Due ${Fmt.relativeDay(invoice.dueDate).toLowerCase()}',
    };

    return AppListTile(
      margin: margin,
      onTap: () => context.push(Routes.invoice(invoice.id)),
      title: client ?? invoice.number,
      subtitle: '${invoice.number}  ·  $dueText',
      subtitleColor: overdue ? AppColors.danger : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ref.money(settled ? invoice.total : invoice.balance), style: AppText.bodyStrong),
          const SizedBox(height: 6),
          status.badge,
        ],
      ),
    );
  }
}
