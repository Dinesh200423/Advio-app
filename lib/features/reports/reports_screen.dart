import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../invoices/invoice_providers.dart';
import '../leads/lead_providers.dart';
import '../projects/project_providers.dart';
import 'report_providers.dart';

enum ReportRange {
  m3('3 months'),
  m6('6 months'),
  m12('12 months'),
  ytd('This year');

  const ReportRange(this.label);
  final String label;

  int get months => switch (this) {
        ReportRange.m3 => 3,
        ReportRange.m6 => 6,
        ReportRange.m12 => 12,
        ReportRange.ytd => DateTime.now().month,
      };

  DateTime get start => DateTime(DateTime.now().year, DateTime.now().month - months + 1);
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.m6;
  bool _loading = false;

  /// The data is local, so we fake a short fetch to exercise the loading state
  /// the real backend will need.
  Future<void> _select(ReportRange r) async {
    if (r == _range) return;
    setState(() {
      _range = r;
      _loading = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Reports',
      header: FilterChipRow<ReportRange>(
        options: ReportRange.values,
        allLabel: null,
        selected: _range,
        labelOf: (r) => r.label,
        onSelected: (r) => _select(r ?? _range),
      ),
      children: [
        if (_loading)
          const _Loading()
        else
          _Body(range: _range),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          SkeletonBox(height: 96),
          SizedBox(height: 12),
          SkeletonBox(height: 280),
          SizedBox(height: 12),
          SkeletonBox(height: 280),
        ],
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.range});
  final ReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(monthlyFinanceProvider(range.months));
    final revenue = data.fold<double>(0, (s, m) => s + m.revenue);
    final expenses = data.fold<double>(0, (s, m) => s + m.expenses);
    final profit = revenue - expenses;
    final margin = revenue == 0 ? 0.0 : profit / revenue;
    String money(double v) => ref.money(v, compact: true);
    final labels = [for (final m in data) m.label];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Revenue', value: money(revenue), caption: 'Payments received', color: AppColors.success),
            MetricCard(label: 'Expenses', value: money(expenses), color: AppColors.danger),
            MetricCard(label: 'Net profit', value: money(profit), caption: profit >= 0 ? 'Positive' : 'Loss', captionColor: profit >= 0 ? AppColors.success : AppColors.danger),
            MetricCard(label: 'Margin', value: '${(margin * 100).round()}%', caption: 'of revenue', color: AppColors.secondary),
          ],
        ),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Monthly revenue',
          subtitle: range.label,
          child: AppLineChart(
            labels: labels,
            format: money,
            series: [ChartSeries(label: 'Revenue', color: AppColors.primary, values: [for (final m in data) m.revenue])],
          ),
        ),
        const SizedBox(height: 16),
        ChartCard(
          title: 'Monthly expenses',
          subtitle: range.label,
          child: AppBarChart(
            labels: labels,
            format: money,
            series: [ChartSeries(label: 'Expenses', color: AppColors.secondary, values: [for (final m in data) m.expenses])],
          ),
        ),
        const SizedBox(height: 16),
        _ProfitSummary(data: data),
        const SizedBox(height: 16),
        _LeadConversion(since: range.start),
        const SizedBox(height: 16),
        const _ProjectStatus(),
        const SizedBox(height: 16),
        const _Receivables(),
      ],
    );
  }
}

class _ProfitSummary extends ConsumerWidget {
  const _ProfitSummary({required this.data});
  final List<MonthPoint> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = data.reversed.toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profit summary', style: AppText.cardTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: Text('Month', style: AppText.caption)),
              Expanded(flex: 3, child: Text('Revenue', textAlign: TextAlign.end, style: AppText.caption)),
              Expanded(flex: 3, child: Text('Expenses', textAlign: TextAlign.end, style: AppText.caption)),
              Expanded(flex: 3, child: Text('Profit', textAlign: TextAlign.end, style: AppText.caption)),
            ],
          ),
          const Divider(height: 20),
          for (final m in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(m.label, style: AppText.labelStrong)),
                  Expanded(flex: 3, child: Text(ref.money(m.revenue, compact: true), textAlign: TextAlign.end, style: AppText.body.copyWith(fontSize: 13))),
                  Expanded(flex: 3, child: Text(ref.money(m.expenses, compact: true), textAlign: TextAlign.end, style: AppText.body.copyWith(fontSize: 13))),
                  Expanded(
                    flex: 3,
                    child: Text(
                      ref.money(m.profit, compact: true),
                      textAlign: TextAlign.end,
                      style: AppText.bodyStrong.copyWith(fontSize: 13, color: m.profit >= 0 ? AppColors.success : AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LeadConversion extends ConsumerWidget {
  const _LeadConversion({required this.since});
  final DateTime since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leads = ref.watch(leadsProvider).where((l) => !l.createdAt.isBefore(since)).toList();
    final won = leads.where((l) => l.status == LeadStatus.won).length;
    final lost = leads.where((l) => l.status == LeadStatus.lost).length;
    final open = leads.length - won - lost;
    final rate = leads.isEmpty ? 0 : (won / leads.length * 100).round();

    return ChartCard(
      title: 'Lead conversion',
      subtitle: '${leads.length} leads created in this period',
      child: leads.isEmpty
          ? const EmptyState(icon: Icons.person_search_outlined, title: 'No leads in this period', compact: true)
          : AppDonutChart(
              centerValue: '$rate%',
              centerLabel: 'converted',
              slices: [
                ChartSlice(label: 'Won', value: won.toDouble(), color: AppColors.success),
                ChartSlice(label: 'In progress', value: open.toDouble(), color: AppColors.primary),
                ChartSlice(label: 'Lost', value: lost.toDouble(), color: AppColors.danger),
              ],
              valueFormat: (v) => v.round().toString(),
            ),
    );
  }
}

class _ProjectStatus extends ConsumerWidget {
  const _ProjectStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return ChartCard(
      title: 'Project status',
      subtitle: '${projects.length} projects',
      child: AppDonutChart(
        centerValue: '${projects.length}',
        centerLabel: 'projects',
        valueFormat: (v) => v.round().toString(),
        slices: [
          for (final s in ProjectStatus.values)
            ChartSlice(label: s.label, value: projects.where((p) => p.status == s).length.toDouble(), color: s.color),
        ],
      ),
    );
  }
}

/// Unpaid balances grouped by how late they are.
class _Receivables extends ConsumerWidget {
  const _Receivables();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(outstandingInvoicesProvider);
    final buckets = <String, double>{'Not due': 0, '1–30 days': 0, '31–60 days': 0, '60+ days': 0};
    for (final i in open) {
      final late = -daysUntil(i.dueDate);
      final key = late <= 0 ? 'Not due' : (late <= 30 ? '1–30 days' : (late <= 60 ? '31–60 days' : '60+ days'));
      buckets[key] = buckets[key]! + i.balance;
    }
    final total = buckets.values.fold<double>(0, (s, v) => s + v);

    return ChartCard(
      title: 'Outstanding payments',
      subtitle: '${ref.money(total)} across ${open.length} invoices',
      child: AppBarChart(
        height: 190,
        labels: buckets.keys.toList(),
        format: (v) => ref.money(v, compact: true),
        series: [ChartSeries(label: 'Outstanding', color: AppColors.warning, values: buckets.values.toList())],
      ),
    );
  }
}
