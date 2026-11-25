import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/quotation.dart';
import '../../shared/widgets/document_widgets.dart';
import '../clients/client_providers.dart';
import '../invoices/invoice_providers.dart';
import 'quotation_providers.dart';

class QuotationDetailScreen extends ConsumerWidget {
  const QuotationDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quotationProvider(id));
    if (q == null) return const MissingRecord(what: 'Quotation', fallback: Routes.quotations);
    final client = ref.watch(clientProvider(q.clientId));
    final status = q.displayStatus;
    final daysLeft = daysUntil(q.validUntil);

    return PageScaffold(
      title: q.number,
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.quotationEdit(id)),
          deleteTitle: 'Delete quotation?',
          deleteMessage: '${q.number} will be permanently removed.',
          onDelete: () {
            ref.read(quotationsProvider.notifier).remove(id);
            context.popOr(Routes.quotations);
            AppSnack.success(context, 'Quotation deleted');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(q.title, style: AppText.sectionTitle)),
                  const SizedBox(width: 8),
                  status.badge,
                ],
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: client == null ? null : () => context.push(Routes.client(client.id)),
                child: Text(client?.displayName ?? 'Unknown client', style: AppText.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              Text(ref.money(q.totals.total), style: AppText.display),
              const SizedBox(height: 4),
              Text(
                switch (status) {
                  QuotationStatus.sent => daysLeft >= 0 ? 'Valid until ${Fmt.date(q.validUntil)} ($daysLeft days left)' : 'Expired on ${Fmt.date(q.validUntil)}',
                  QuotationStatus.expired => 'Expired on ${Fmt.date(q.validUntil)}',
                  _ => 'Valid until ${Fmt.date(q.validUntil)}',
                },
                style: AppText.label.copyWith(color: status == QuotationStatus.expired ? AppColors.warning : AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Actions(quotation: q),
        const SizedBox(height: 24),
        Text('Line items', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              for (final i in q.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.description, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                            Text('${i.quantity == i.quantity.roundToDouble() ? i.quantity.toStringAsFixed(0) : i.quantity} × ${ref.money(i.unitPrice)}', style: AppText.caption),
                          ],
                        ),
                      ),
                      Text(ref.money(i.total), style: AppText.bodyStrong),
                    ],
                  ),
                ),
              const Divider(height: 24),
              TotalsSummary(items: q.items, discountPercent: q.discountPercent, taxPercent: q.taxPercent),
            ],
          ),
        ),
        if (q.notes.isNotEmpty || q.terms.isNotEmpty) ...[
          const SizedBox(height: 16),
          InfoCard(children: [
            if (q.notes.isNotEmpty) InfoRow(label: 'Notes', value: q.notes),
            if (q.terms.isNotEmpty) InfoRow(label: 'Terms', value: q.terms),
          ]),
        ],
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.quotation});
  final Quotation quotation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(quotationsProvider.notifier);
    final client = ref.watch(clientProvider(quotation.clientId));
    final status = quotation.displayStatus;

    final preview = AppButton.secondary(label: 'Preview & PDF', onPressed: () => context.push(Routes.quotationPreview(quotation.id)));

    switch (status) {
      case QuotationStatus.draft:
        return Row(
          children: [
            Expanded(child: preview),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Send to client',
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Send quotation?',
                    message: '${quotation.number} will be emailed to ${client?.email ?? 'the client'}. In this demo nothing is actually sent.',
                    confirmLabel: 'Send',
                  );
                  if (!ok || !context.mounted) return;
                  notifier.setStatus(quotation.id, QuotationStatus.sent);
                  AppSnack.success(context, 'Quotation sent to ${client?.displayName ?? 'client'}');
                },
              ),
            ),
          ],
        );
      case QuotationStatus.sent:
      case QuotationStatus.expired:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Mark accepted',
                    onPressed: () {
                      notifier.setStatus(quotation.id, QuotationStatus.accepted);
                      AppSnack.success(context, 'Marked as accepted');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.secondary(
                    label: 'Mark rejected',
                    onPressed: () {
                      notifier.setStatus(quotation.id, QuotationStatus.rejected);
                      AppSnack.info(context, 'Marked as rejected');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: preview),
          ],
        );
      case QuotationStatus.accepted:
        return Column(
          children: [
            AppButton(
              label: 'Create invoice',
              onPressed: () {
                final invoice = ref.read(invoicesProvider.notifier).fromQuotation(quotation);
                AppSnack.success(context, 'Draft invoice ${invoice.number} created');
                context.push(Routes.invoice(invoice.id));
              },
            ),
            const SizedBox(height: 12),
            preview,
          ],
        );
      case QuotationStatus.rejected:
        return Column(
          children: [
            AppButton.secondary(
              label: 'Reopen as draft',
              onPressed: () => notifier.setStatus(quotation.id, QuotationStatus.draft),
            ),
            const SizedBox(height: 12),
            preview,
          ],
        );
    }
  }
}
