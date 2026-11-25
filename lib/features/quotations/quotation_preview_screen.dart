import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../shared/pdf/document_pdf.dart';
import '../../shared/widgets/document_widgets.dart';
import '../settings/settings_providers.dart';
import '../clients/client_providers.dart';
import 'quotation_providers.dart';

class QuotationPreviewScreen extends ConsumerWidget {
  const QuotationPreviewScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quotationProvider(id));
    if (q == null) return const MissingRecord(what: 'Quotation', fallback: Routes.quotations);

    return PageScaffold(
      title: 'Preview',
      children: [
        DocumentPreview(
          kind: 'QUOTATION',
          number: q.number,
          client: ref.watch(clientProvider(q.clientId)),
          title: q.title,
          items: q.items,
          discountPercent: q.discountPercent,
          taxPercent: q.taxPercent,
          issueDate: q.issueDate,
          secondDateLabel: 'Valid until',
          secondDate: q.validUntil,
          notes: q.notes,
          terms: q.terms,
          statusLabel: q.displayStatus.label,
        ),
        const SizedBox(height: 20),
        DownloadPdfButton(
          data: DocumentData.quotation(q, client: ref.watch(clientProvider(q.clientId)), settings: ref.watch(settingsProvider)),
        ),
      ],
    );
  }
}
