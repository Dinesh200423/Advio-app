import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/invoice.dart';
import '../../shared/widgets/document_widgets.dart';
import '../clients/client_providers.dart';
import '../projects/project_providers.dart';
import 'invoice_providers.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(id));
    if (invoice == null) return const MissingRecord(what: 'Invoice', fallback: Routes.invoices);
    final notifier = ref.read(invoicesProvider.notifier);
    final status = invoice.displayStatus;

    return PageScaffold(
      title: invoice.number,
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.invoiceEdit(id)),
          deleteTitle: 'Delete invoice?',
          deleteMessage: '${invoice.number} and its payment records will be permanently removed.',
          extra: [
            if (status != InvoiceStatus.voided) const PopupMenuItem(value: 'void', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Void invoice'), contentPadding: EdgeInsets.zero)),
          ],
          onExtra: (v) async {
            if (v != 'void') return;
            final ok = await confirmDialog(
              context,
              title: 'Void this invoice?',
              message: 'It will no longer count as receivable. Recorded payments stay on file.',
              confirmLabel: 'Void invoice',
              destructive: true,
            );
            if (ok && context.mounted) {
              notifier.voidInvoice(id);
              AppSnack.info(context, '${invoice.number} voided');
            }
          },
          onDelete: () {
            notifier.remove(id);
            context.popOr(Routes.invoices);
            AppSnack.success(context, 'Invoice deleted');
          },
        ),
      ],
      children: [
        _Summary(invoice: invoice),
        const SizedBox(height: 16),
        _Actions(invoice: invoice),
        const SizedBox(height: 20),
        TabbedSection(
          tabs: {
            'Details': (_) => _Details(invoice: invoice),
            'Payments (${invoice.payments.length})': (_) => _Payments(invoice: invoice),
          },
        ),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider(invoice.clientId));
    final status = invoice.displayStatus;
    final overdue = status == InvoiceStatus.overdue;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: client == null ? null : () => context.push(Routes.client(client.id)),
                  child: Text(client?.displayName ?? 'Unknown client', style: AppText.sectionTitle),
                ),
              ),
              status.badge,
            ],
          ),
          const SizedBox(height: 16),
          Text(ref.money(invoice.total), style: AppText.display),
          Text('Invoice total', style: AppText.label),
          if (invoice.status != InvoiceStatus.draft && invoice.status != InvoiceStatus.voided) ...[
            const SizedBox(height: 16),
            AppProgressBar(value: invoice.total == 0 ? 0 : invoice.paid / invoice.total, color: AppColors.success),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Figure(label: 'Paid', value: ref.money(invoice.paid))),
                Expanded(child: _Figure(label: 'Balance due', value: ref.money(invoice.balance), color: overdue ? AppColors.danger : null)),
                Expanded(child: _Figure(label: overdue ? 'Was due' : 'Due', value: Fmt.dateShort(invoice.dueDate), color: overdue ? AppColors.danger : null)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});
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

class _Actions extends ConsumerWidget {
  const _Actions({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = invoice.displayStatus;
    final preview = AppButton.secondary(label: 'Preview', onPressed: () => context.push(Routes.invoicePreview(invoice.id)));

    if (status == InvoiceStatus.draft) {
      return Row(
        children: [
          Expanded(child: preview),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              label: 'Send invoice',
              onPressed: () async {
                final client = ref.read(clientProvider(invoice.clientId));
                final ok = await confirmDialog(
                  context,
                  title: 'Send invoice?',
                  message: '${invoice.number} will be emailed to ${client?.email ?? 'the client'}. In this demo nothing is actually sent.',
                  confirmLabel: 'Send',
                );
                if (ok && context.mounted) {
                  ref.read(invoicesProvider.notifier).send(invoice.id);
                  AppSnack.success(context, 'Invoice sent');
                }
              },
            ),
          ),
        ],
      );
    }
    if (invoice.isOutstanding) {
      return Row(
        children: [
          Expanded(child: preview),
          const SizedBox(width: 12),
          Expanded(child: AppButton(label: 'Record payment', onPressed: () => context.push(Routes.invoicePayment(invoice.id)))),
        ],
      );
    }
    return preview;
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = invoice.projectId == null ? null : ref.watch(projectProvider(invoice.projectId!));
    final late = invoice.displayStatus == InvoiceStatus.overdue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(children: [
          InfoRow(label: 'Issue date', value: Fmt.date(invoice.issueDate)),
          InfoRow(label: 'Due date', value: Fmt.date(invoice.dueDate), valueColor: late ? AppColors.danger : null),
          InfoRow(label: 'Project', value: project?.name ?? '', onTap: project == null ? null : () => context.push(Routes.project(project.id))),
          if (invoice.notes.isNotEmpty) InfoRow(label: 'Notes', value: invoice.notes),
        ]),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              for (final i in invoice.items)
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
              TotalsSummary(items: invoice.items, discountPercent: invoice.discountPercent, taxPercent: invoice.taxPercent),
            ],
          ),
        ),
      ],
    );
  }
}

class _Payments extends ConsumerWidget {
  const _Payments({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invoice.payments.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No payments recorded',
        message: invoice.status == InvoiceStatus.draft ? 'Send the invoice before recording payments.' : 'Record a payment when money comes in.',
        compact: true,
        actionLabel: invoice.isOutstanding ? 'Record payment' : null,
        onAction: () => context.push(Routes.invoicePayment(invoice.id)),
      );
    }
    final sorted = [...invoice.payments]..sort((a, b) => b.date.compareTo(a.date));
    return AppCard(
      child: Timeline(
        entries: [
          for (final p in sorted)
            TimelineEntry(
              title: ref.money(p.amount),
              subtitle: [p.method.label, if (p.reference.isNotEmpty) 'Ref ${p.reference}', if (p.note.isNotEmpty) p.note].join(' · '),
              time: Fmt.date(p.date),
              color: AppColors.success,
              trailing: IconButton(
                tooltip: 'Delete payment',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                onPressed: () async {
                  final ok = await confirmDialog(context, title: 'Delete payment?', message: '${ref.money(p.amount)} on ${Fmt.date(p.date)} will be removed from this invoice.', confirmLabel: 'Delete', destructive: true);
                  if (ok) ref.read(invoicesProvider.notifier).deletePayment(invoice.id, p.id);
                },
              ),
            ),
        ],
      ),
    );
  }
}
