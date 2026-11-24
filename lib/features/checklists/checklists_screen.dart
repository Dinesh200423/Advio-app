import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/checklist.dart';
import '../clients/client_providers.dart';
import '../projects/project_providers.dart';
import 'checklist_providers.dart';
import 'widgets/checklist_summary_card.dart';
import 'widgets/new_checklist_sheet.dart';

/// Every project checklist in one place, with what needs attention across them.
class ChecklistsScreen extends ConsumerStatefulWidget {
  const ChecklistsScreen({super.key});

  @override
  ConsumerState<ChecklistsScreen> createState() => _ChecklistsScreenState();
}

class _ChecklistsScreenState extends ConsumerState<ChecklistsScreen> {
  String _query = '';
  StageStatus? _status;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(checklistsProvider);
    final q = _query.trim().toLowerCase();

    bool matches(ProjectChecklist c) {
      if (_status != null && c.status != _status) return false;
      if (q.isEmpty) return true;
      final project = ref.read(projectProvider(c.projectId));
      final client = project == null ? '' : ref.read(clientNameProvider(project.clientId));
      return (project?.name ?? '').toLowerCase().contains(q) || client.toLowerCase().contains(q) || c.templateName.toLowerCase().contains(q);
    }

    // Unfinished work first, most blocked at the top.
    final list = all.where(matches).toList()
      ..sort((a, b) {
        if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
        final blocked = b.blockedStageCount.compareTo(a.blockedStageCount);
        return blocked != 0 ? blocked : a.progress.compareTo(b.progress);
      });

    final active = all.where((c) => !c.isComplete).toList();
    final waiting = all.fold<int>(0, (s, c) => s + c.waitingCount);
    final overdue = all.fold<int>(0, (s, c) => s + c.overdueCount);
    final blocked = all.fold<int>(0, (s, c) => s + c.blockedStageCount);
    final filtering = q.isNotEmpty || _status != null;

    return PageScaffold(
      title: 'Delivery checklists',
      actions: [
        TextButton(onPressed: () => context.push(Routes.templates), child: const Text('Templates')),
      ],
      onRefresh: () => mockRefresh(context),
      fab: FloatingActionButton.extended(
        onPressed: () => showNewChecklistSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New checklist'),
      ),
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Active checklists', value: '${active.length}', caption: '${all.length - active.length} completed'),
            MetricCard(label: 'Waiting on client', value: '$waiting', color: AppColors.warning, caption: waiting == 0 ? 'Nothing held up' : 'across projects', captionColor: waiting == 0 ? AppColors.success : AppColors.warning),
            MetricCard(label: 'Blocked stages', value: '$blocked', color: AppColors.danger),
            MetricCard(label: 'Overdue items', value: '$overdue', color: AppColors.danger, caption: overdue == 0 ? 'All on schedule' : 'need attention', captionColor: overdue == 0 ? AppColors.success : AppColors.danger),
          ],
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search project, client or service', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<StageStatus>(
          options: StageStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          countOf: (s) => s == null ? all.length : all.where((c) => c.status == s).length,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.fact_check_outlined,
            title: filtering ? 'No checklists match' : 'No checklists yet',
            message: filtering ? 'Try another search or status.' : 'Start one from a service template to track delivery for a project.',
            actionLabel: filtering ? 'Clear filters' : 'New checklist',
            onAction: filtering
                ? () => setState(() {
                      _query = '';
                      _status = null;
                    })
                : () => showNewChecklistSheet(context),
          )
        else
          for (final c in list) ChecklistSummaryCard(checklist: c),
      ],
    );
  }
}
