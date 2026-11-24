import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../clients/client_providers.dart';
import 'quotation_providers.dart';
import 'widgets/quotation_tile.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  String _query = '';
  QuotationStatus? _status;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(quotationsProvider);
    final q = _query.trim().toLowerCase();

    final list = all.where((x) {
      if (_status != null && x.displayStatus != _status) return false;
      if (q.isEmpty) return true;
      final client = ref.read(clientNameProvider(x.clientId)).toLowerCase();
      return x.title.toLowerCase().contains(q) || x.number.toLowerCase().contains(q) || client.contains(q);
    }).toList()
      ..sort((a, b) => b.issueDate.compareTo(a.issueDate));

    double sumOf(bool Function(QuotationStatus s) test) =>
        all.where((x) => test(x.displayStatus)).fold(0.0, (s, x) => s + x.totals.total);

    final awaiting = all.where((x) => x.displayStatus == QuotationStatus.sent).toList();
    final accepted = all.where((x) => x.displayStatus == QuotationStatus.accepted).length;
    final closed = all.where((x) => const [QuotationStatus.accepted, QuotationStatus.rejected, QuotationStatus.expired].contains(x.displayStatus)).length;
    final winRate = closed == 0 ? 0 : (accepted / closed * 100).round();
    final filtering = q.isNotEmpty || _status != null;

    return PageScaffold(
      title: 'Quotations',
      onRefresh: () => mockRefresh(context),
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.quotationNew()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New quotation'),
      ),
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Total quoted', value: ref.money(sumOf((s) => s != QuotationStatus.draft), compact: true), caption: '${all.length} quotations'),
            MetricCard(
              label: 'Awaiting reply',
              value: ref.money(sumOf((s) => s == QuotationStatus.sent), compact: true),
              caption: '${awaiting.length} sent',
              color: AppColors.warning,
            ),
            MetricCard(label: 'Accepted', value: ref.money(sumOf((s) => s == QuotationStatus.accepted), compact: true), caption: '$accepted won', color: AppColors.success),
            MetricCard(label: 'Win rate', value: '$winRate%', caption: 'of $closed decided', color: AppColors.secondary),
          ],
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search by title, number or client', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<QuotationStatus>(
          options: QuotationStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          countOf: (s) => s == null ? all.length : all.where((x) => x.displayStatus == s).length,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.request_quote_outlined,
            title: filtering ? 'No quotations match' : 'No quotations yet',
            message: filtering ? 'Try a different search or status.' : 'Create a quotation to send your first proposal.',
            actionLabel: filtering ? null : 'New quotation',
            onAction: () => context.push(Routes.quotationNew()),
          )
        else
          for (final x in list) QuotationTile(quotation: x),
      ],
    );
  }
}
