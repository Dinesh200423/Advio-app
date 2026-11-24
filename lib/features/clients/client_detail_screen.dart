import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/client.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/notes_section.dart';
import '../invoices/invoice_providers.dart';
import '../invoices/widgets/invoice_tile.dart';
import '../projects/project_providers.dart';
import '../projects/widgets/project_tile.dart';
import '../quotations/quotation_providers.dart';
import '../quotations/widgets/quotation_tile.dart';
import 'client_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider(id));
    if (client == null) return const MissingRecord(what: 'Client', fallback: Routes.clients);

    return PageScaffold(
      title: 'Client details',
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.clientEdit(id)),
          deleteTitle: 'Delete client?',
          deleteMessage: '${client.displayName} will be removed. Their projects and invoices are kept.',
          onDelete: () {
            ref.read(clientsProvider.notifier).remove(id);
            context.popOr(Routes.clients);
            AppSnack.success(context, 'Client deleted');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  InitialsAvatar(name: client.displayName, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.displayName, style: AppText.sectionTitle),
                        Text(client.company.isNotEmpty ? client.name : client.email, style: AppText.label),
                        const SizedBox(height: 6),
                        client.status.badge,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ContactActions(phone: client.phone, email: client.email),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TabbedSection(
          tabs: {
            'Overview': (_) => _Overview(client: client),
            'Work': (_) => _Work(client: client),
            'Billing': (_) => _Billing(client: client),
            'Notes': (_) => _NotesAndActivity(client: client),
          },
        ),
      ],
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(clientInvoicesProvider(client.id));
    final outstanding = invoices.where((i) => i.isOutstanding).fold<double>(0, (s, i) => s + i.balance);
    final projects = ref.watch(clientProjectsProvider(client.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Lifetime value', value: ref.money(ref.watch(clientLifetimeValueProvider(client.id)), compact: true), color: AppColors.success),
            MetricCard(
              label: 'Outstanding',
              value: ref.money(outstanding, compact: true),
              color: outstanding > 0 ? AppColors.warning : AppColors.muted,
            ),
            MetricCard(label: 'Projects', value: '${projects.length}', caption: '${projects.where((p) => p.status == ProjectStatus.active).length} active'),
            MetricCard(label: 'Client since', value: Fmt.month(client.createdAt), color: AppColors.secondary, caption: '${client.createdAt.year}'),
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'Contact information',
          children: [
            InfoRow(icon: Icons.person_outline_rounded, label: 'Contact', value: client.name),
            InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: client.email),
            InfoRow(icon: Icons.call_outlined, label: 'Phone', value: client.phone),
            InfoRow(icon: Icons.language_rounded, label: 'Website', value: client.website),
            InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: client.address),
          ],
        ),
      ],
    );
  }
}

class _Work extends ConsumerWidget {
  const _Work({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(clientProjectsProvider(client.id));
    final quotes = ref.watch(clientQuotationsProvider(client.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Projects', padding: const EdgeInsets.only(bottom: 12), actionLabel: 'New', onAction: () => context.push(Routes.projectNew(clientId: client.id))),
        if (projects.isEmpty) const EmptyState(icon: Icons.folder_open_rounded, title: 'No projects yet', compact: true) else for (final p in projects) ProjectTile(project: p, showClient: false),
        SectionHeader(title: 'Quotations', padding: const EdgeInsets.only(top: 12, bottom: 12), actionLabel: 'New', onAction: () => context.push(Routes.quotationNew(clientId: client.id))),
        if (quotes.isEmpty) const EmptyState(icon: Icons.request_quote_outlined, title: 'No quotations yet', compact: true) else for (final q in quotes) QuotationTile(quotation: q, showClient: false),
      ],
    );
  }
}

class _Billing extends ConsumerWidget {
  const _Billing({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(clientInvoicesProvider(client.id));
    final payments = ref.watch(clientPaymentsProvider(client.id));
    final byId = {for (final i in invoices) i.id: i};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Invoices', padding: const EdgeInsets.only(bottom: 12), actionLabel: 'New', onAction: () => context.push(Routes.invoiceNew(clientId: client.id))),
        if (invoices.isEmpty) const EmptyState(icon: Icons.receipt_long_outlined, title: 'No invoices yet', compact: true) else for (final i in invoices) InvoiceTile(invoice: i, showClient: false),
        const SectionHeader(title: 'Payment history', padding: EdgeInsets.only(top: 12, bottom: 12)),
        if (payments.isEmpty)
          const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No payments yet', compact: true)
        else
          AppCard(
            child: Timeline(
              entries: [
                for (final p in payments)
                  TimelineEntry(
                    title: ref.money(p.amount),
                    subtitle: '${byId[p.invoiceId]?.number ?? ''} · ${p.method.label}',
                    time: Fmt.date(p.date),
                    color: AppColors.success,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NotesAndActivity extends ConsumerWidget {
  const _NotesAndActivity({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NotesSection(notes: client.notes, onAdd: (t) => ref.read(clientsProvider.notifier).addNote(client.id, t)),
        const SectionHeader(title: 'Activity timeline'),
        AppCard(
          child: client.history.isEmpty
              ? const EmptyState(icon: Icons.history_rounded, title: 'No activity yet', compact: true)
              : Timeline(entries: [for (final a in client.history) TimelineEntry(title: a.title, subtitle: a.detail, time: Fmt.dateTime(a.at), color: a.kind.color)]),
        ),
      ],
    );
  }
}
