import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/lead.dart';
import '../team/team_providers.dart';
import 'lead_providers.dart';
import 'widgets/lead_tile.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key, this.dueOnly = false, this.initialOwner});

  /// Start with only leads whose follow-up is due (from the dashboard).
  final bool dueOnly;

  /// Start filtered to one owner (a member id), or "none" for unassigned.
  final String? initialOwner;

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  String _query = '';
  LeadStatus? _status;
  LeadSource? _source;
  ServiceInterest? _service;
  late String? _owner = widget.initialOwner == 'none' ? '__none' : widget.initialOwner; // a member id, '__none' for unassigned, null for anyone
  late bool _dueOnly = widget.dueOnly;

  List<Lead> _apply(List<Lead> all, Set<String> dueIds) {
    final q = _query.trim().toLowerCase();
    return all.where((l) {
      if (_status != null && l.status != _status) return false;
      if (_source != null && l.source != _source) return false;
      if (_service != null && l.service != _service) return false;
      if (_owner == '__none' && l.ownerId != null) return false;
      if (_owner != null && _owner != '__none' && l.ownerId != _owner) return false;
      if (_dueOnly && !dueIds.contains(l.id)) return false;
      if (q.isEmpty) return true;
      return l.name.toLowerCase().contains(q) ||
          l.company.toLowerCase().contains(q) ||
          l.email.toLowerCase().contains(q) ||
          l.location.toLowerCase().contains(q) ||
          l.phone.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(leadsProvider);
    final due = ref.watch(dueFollowUpsProvider);
    final dueIds = {for (final d in due) d.lead.id};
    final leads = _apply(all, dueIds);

    final open = all.where((l) => l.status.isOpen);
    final pipeline = open.fold<double>(0, (s, l) => s + l.estimatedValue);
    final won = all.where((l) => l.status == LeadStatus.won).length;
    final conversion = all.isEmpty ? 0.0 : won / all.length;
    final filtering = _query.isNotEmpty || _status != null || _source != null || _service != null || _owner != null || _dueOnly;

    return PageScaffold(
      title: 'Leads',
      subtitle: '${open.length} open · ${ref.money(pipeline, compact: true)} in pipeline',
      large: true,
      onRefresh: () => pullToRefresh(context),
      actions: [
        TextButton(onPressed: () => context.push(Routes.leadQuickAdd), child: const Text('Quick add')),
        IconButton.filled(
          tooltip: 'Add lead',
          onPressed: () => context.push(Routes.leadNew),
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
        ),
      ],
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Total leads', value: '${all.length}', caption: '${open.length} open'),
            MetricCard(label: 'Pipeline value', value: ref.money(pipeline, compact: true), color: AppColors.secondary),
            MetricCard(
              label: 'Follow-ups due',
              value: '${due.length}',
              color: AppColors.warning,
              caption: due.isEmpty ? 'All clear' : 'Tap to view',
              onTap: due.isEmpty ? null : () => setState(() => _dueOnly = true),
            ),
            MetricCard(label: 'Conversion', value: '${(conversion * 100).round()}%', color: AppColors.success, caption: '$won won'),
          ],
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search name, area, phone or email', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<LeadStatus>(
          options: LeadStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          countOf: (s) => s == null ? all.length : all.where((l) => l.status == s).length,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: FilterDropdown<ServiceInterest>(hint: 'Any service', value: _service, items: ServiceInterest.values, labelOf: (s) => s.shortLabel, onChanged: (v) => setState(() => _service = v))),
            const SizedBox(width: 8),
            Expanded(child: FilterDropdown<LeadSource>(hint: 'Any source', value: _source, items: LeadSource.values, labelOf: (s) => s.label, onChanged: (v) => setState(() => _source = v))),
          ],
        ),
        const SizedBox(height: 8),
        FilterDropdown<String>(
          hint: 'Any owner',
          value: _owner,
          items: ['__none', for (final m in ref.watch(teamProvider)) m.id],
          labelOf: (id) => id == '__none' ? 'Unassigned' : ref.read(memberNameProvider(id)),
          onChanged: (v) => setState(() => _owner = v),
        ),
        if (_dueOnly)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: const Text('Follow-up due'),
                avatar: const Icon(Icons.event_available_rounded, size: 16, color: AppColors.warning),
                onDeleted: () => setState(() => _dueOnly = false),
                backgroundColor: AppColors.tint(AppColors.warning, 0.1),
                side: BorderSide.none,
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (leads.isEmpty)
          EmptyState(
            icon: filtering ? Icons.search_off_rounded : Icons.person_search_rounded,
            title: filtering ? 'No leads match' : 'No leads yet',
            message: filtering ? 'Try a different search or clear the filters.' : 'Add your first lead to start tracking your pipeline.',
            actionLabel: filtering ? 'Clear filters' : 'Add lead',
            onAction: filtering
                ? () => setState(() {
                      _query = '';
                      _status = null;
                      _source = null;
                      _service = null;
                      _owner = null;
                      _dueOnly = false;
                    })
                : () => context.push(Routes.leadNew),
          )
        else
          for (final l in leads) LeadTile(lead: l),
      ],
    );
  }
}
