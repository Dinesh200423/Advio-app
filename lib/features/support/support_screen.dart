import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/support.dart';
import '../clients/client_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'support_providers.dart';

/// Support dashboard: tickets and maintenance plans.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(ticketsProvider);
    final active = tickets.where((t) => t.status.isActive).toList();
    final urgent = active.where((t) => t.priority == Priority.urgent || t.priority == Priority.high).length;
    final resolved = tickets.where((t) => !t.status.isActive).length;

    return PageScaffold(
      title: 'Support & Maintenance',
      onRefresh: () => mockRefresh(context),
      fab: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.ticketNew()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New ticket'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _addPlan(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New plan'),
            ),
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Open tickets', value: '${active.length}', caption: '$urgent high priority', captionColor: urgent > 0 ? AppColors.warning : null),
            MetricCard(label: 'Resolved', value: '$resolved', caption: 'of ${tickets.length} total', color: AppColors.success),
            MetricCard(label: 'Monthly recurring', value: ref.money(ref.watch(monthlyRecurringProvider), compact: true), caption: '${ref.watch(plansProvider).where((p) => p.active).length} active plans', color: AppColors.secondary),
            MetricCard(label: 'Oldest open', value: active.isEmpty ? '—' : '${(-daysUntil(active.map((t) => t.createdAt).reduce((a, b) => a.isBefore(b) ? a : b)))}d', caption: 'days waiting'),
          ],
        ),
        const SizedBox(height: 24),
        SegmentedTabs(labels: const ['Tickets', 'Maintenance plans'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        const SizedBox(height: 20),
        if (_tab == 0) const _Tickets() else const _Plans(),
      ],
    );
  }

  void _addPlan(BuildContext context) {
    final name = TextEditingController();
    final fee = TextEditingController();
    String? clientId;
    final key = GlobalKey<FormState>();
    final clients = ref.read(clientsProvider);

    showAppSheet<void>(
      context,
      title: 'New maintenance plan',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Form(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdown<String>(
                label: 'Client',
                required: true,
                items: [for (final c in clients) c.id],
                value: clientId,
                labelOf: (id) => clients.firstWhere((c) => c.id == id).displayName,
                validator: (v) => v == null ? 'Choose a client' : null,
                onChanged: (v) => setState(() => clientId = v),
              ),
              const SizedBox(height: 16),
              AppTextField(controller: name, label: 'Plan name', required: true, hint: 'e.g. Essential Care Plan', validator: (v) => Validators.required(v, 'Plan name')),
              const SizedBox(height: 16),
              AppAmountField(controller: fee, label: 'Monthly fee', required: true, validator: (v) => Validators.amount(v, label: 'Fee')),
              const SizedBox(height: 24),
              AppButton(
                label: 'Create plan',
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  ref.read(plansProvider.notifier).upsert(MaintenancePlan(
                        id: newId('plan'),
                        clientId: clientId!,
                        name: name.text.trim(),
                        monthlyFee: parseAmount(fee.text),
                        nextReview: DateTime.now().add(const Duration(days: 30)),
                      ));
                  Navigator.pop(ctx);
                  AppSnack.success(context, 'Maintenance plan created');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tickets extends ConsumerStatefulWidget {
  const _Tickets();

  @override
  ConsumerState<_Tickets> createState() => _TicketsState();
}

class _TicketsState extends ConsumerState<_Tickets> {
  TicketStatus? _status;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(ticketsProvider);
    final q = _query.trim().toLowerCase();
    final list = all.where((t) {
      if (_status != null && t.status != _status) return false;
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) || t.number.toLowerCase().contains(q) || ref.read(clientNameProvider(t.clientId)).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        // Active tickets first, then most urgent, then newest.
        if (a.status.isActive != b.status.isActive) return a.status.isActive ? -1 : 1;
        final p = b.priority.index.compareTo(a.priority.index);
        return p != 0 ? p : b.createdAt.compareTo(a.createdAt);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchBar(hint: 'Search tickets', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<TicketStatus>(
          options: TicketStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          countOf: (s) => s == null ? all.length : all.where((t) => t.status == s).length,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const EmptyState(icon: Icons.inbox_outlined, title: 'No tickets', message: 'Nothing matches this filter.', compact: true)
        else
          for (final t in list)
            AppListTile(
              onTap: () => context.push(Routes.ticket(t.id)),
              title: t.title,
              subtitle: '${t.number}  ·  ${ref.watch(clientNameProvider(t.clientId))}',
              meta: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [t.status.badge, t.priority.badge, AssigneeAvatar(memberId: t.assigneeId, size: 22)]),
              trailing: Text(Fmt.timeAgo(t.createdAt), style: AppText.caption),
            ),
      ],
    );
  }
}

class _Plans extends ConsumerWidget {
  const _Plans();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    if (plans.isEmpty) {
      return const EmptyState(icon: Icons.build_circle_outlined, title: 'No maintenance plans', message: 'Recurring care plans for clients appear here.', compact: true);
    }
    return Column(
      children: [
        for (final p in plans)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: AppText.cardTitle.copyWith(fontSize: 15)),
                          Text(ref.watch(clientNameProvider(p.clientId)), style: AppText.label),
                        ],
                      ),
                    ),
                    Switch(
                      value: p.active,
                      onChanged: (_) {
                        ref.read(plansProvider.notifier).toggle(p.id);
                        AppSnack.info(context, p.active ? '${p.name} paused' : '${p.name} activated');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: ref.money(p.monthlyFee), style: AppText.metric.copyWith(fontSize: 22)),
                    TextSpan(text: ' / month', style: AppText.label),
                  ]),
                ),
                const SizedBox(height: 12),
                for (final item in p.includes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(top: 7, right: 10), child: SizedBox(width: 4, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.muted, shape: BoxShape.circle)))),
                        Expanded(child: Text(item, style: AppText.body.copyWith(fontSize: 13.5))),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  !p.active ? 'Paused' : (daysUntil(p.nextReview) < 0 ? 'Review overdue since ${Fmt.date(p.nextReview)}' : 'Next review ${Fmt.date(p.nextReview)}'),
                  style: AppText.caption.copyWith(color: p.active && daysUntil(p.nextReview) < 0 ? AppColors.danger : AppColors.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
