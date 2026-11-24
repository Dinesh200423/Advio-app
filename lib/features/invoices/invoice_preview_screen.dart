import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets/document_widgets.dart';
import '../clients/client_providers.dart';
import 'invoice_providers.dart';

class InvoicePreviewScreen extends ConsumerWidget {
  const InvoicePreviewScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(id));
    if (invoice == null) return const MissingRecord(what: 'Invoice', fallback: Routes.invoices);
    final showPaid = invoice.paid > 0;

    return PageScaffold(
      title: 'Preview',
      children: [
        DocumentPreview(
          kind: 'INVOICE',
          number: invoice.number,
          client: ref.watch(clientProvider(invoice.clientId)),
          items: invoice.items,
          discountPercent: invoice.discountPercent,
          taxPercent: invoice.taxPercent,
          issueDate: invoice.issueDate,
          secondDateLabel: 'Due date',
          secondDate: invoice.dueDate,
          notes: invoice.notes,
          statusLabel: invoice.displayStatus.label,
          totalsExtra: [
            if (showPaid) ('Paid', '- ${ref.money(invoice.paid)}', strong: false),
            if (showPaid && invoice.displayStatus != InvoiceStatus.voided) ('Balance due', ref.money(invoice.balance), strong: true),
          ],
        ),
        const SizedBox(height: 20),
        AppButton.secondary(
          label: 'Download PDF',
          icon: Icons.download_rounded,
          onPressed: () => AppSnack.info(context, 'PDF export is not part of the prototype yet'),
        ),
      ],
    );
  }
}
