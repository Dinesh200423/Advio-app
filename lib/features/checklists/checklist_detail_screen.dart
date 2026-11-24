import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/checklist.dart';
import '../clients/client_providers.dart';
import '../projects/project_providers.dart';
import '../team/team_providers.dart';
import 'checklist_providers.dart';
import 'widgets/checklist_style.dart';
import 'widgets/item_actions.dart';
import 'widgets/item_detail_sheet.dart';
import 'widgets/item_tile.dart';
import 'widgets/stage_widgets.dart';

enum ItemFilter {
  all('All items'),
  mine('Assigned to me'),
  pending('Pending'),
  waiting('Waiting on client'),
  overdue('Overdue');

  const ItemFilter(this.label);
  final String label;

  /// [me] is the id of whoever is using the app.
  bool matches(ChecklistItem i, String me) => switch (this) {
        ItemFilter.all => true,
        ItemFilter.pending => i.isApplicable && !i.isResolved,
        ItemFilter.waiting => i.status == ChecklistItemStatus.waitingClient,
        ItemFilter.overdue => i.isOverdue,
        ItemFilter.mine => i.assigneeId == me && i.isApplicable && !i.isResolved,
      };
}

/// One project's delivery checklist: overview on top, stages as an accordion below.
class ChecklistDetailScreen extends ConsumerStatefulWidget {
  const ChecklistDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ChecklistDetailScreen> createState() => _ChecklistDetailScreenState();
}

class _ChecklistDetailScreenState extends ConsumerState<ChecklistDetailScreen> {
  final Set<String> _expanded = {};
  final Map<String, GlobalKey> _keys = {};
  bool _initialised = false;
  ItemFilter _filter = ItemFilter.all;

  GlobalKey _keyFor(String stageId) => _keys.putIfAbsent(stageId, GlobalKey.new);

  void _jumpTo(ChecklistStage stage) {
    setState(() => _expanded.add(stage.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyFor(stage.id).currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, alignment: 0.05);
    });
  }

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(checklistProvider(widget.id));
    if (checklist == null) return const MissingRecord(what: 'Checklist', fallback: Routes.checklists);

    // Open the stage you are working in the first time the page shows.
    if (!_initialised) {
      _initialised = true;
      final current = checklist.currentStage;
      if (current != null) _expanded.add(current.id);
    }

    final me = ref.watch(currentMemberIdProvider);
    final project = ref.watch(projectProvider(checklist.projectId));
    final client = project == null ? null : ref.watch(clientProvider(project.clientId));
    final stages = checklist.stages;
    final filtering = _filter != ItemFilter.all;
    final allOpen = stages.every((s) => _expanded.contains(s.id));

    return PageScaffold(
      title: 'Checklist',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) async {
            if (v != 'delete') return;
            final ok = await confirmDialog(
              context,
              title: 'Delete this checklist?',
              message: 'Progress, notes and evidence for "${project?.name ?? checklist.templateName}" will be removed. The template is not affected.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (ok && context.mounted) {
              ref.read(checklistsProvider.notifier).remove(widget.id);
              context.popOr(Routes.checklists);
              AppSnack.success(context, 'Checklist deleted');
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete checklist', style: TextStyle(color: AppColors.danger)))],
        ),
      ],
      children: [
        _Overview(checklist: checklist, projectName: project?.name, clientName: client?.displayName, onOpenProject: project == null ? null : () => context.push(Routes.project(project.id))),
        const SizedBox(height: 12),
        _Stats(checklist: checklist),
        const SizedBox(height: 12),
        _NextAction(checklist: checklist, onOpen: (item) => showItemDetail(context, checklist.id, item.id)),
        if (checklist.servicePeriod != null) ...[
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'Start next month\'s checklist',
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Start next month?',
                message: 'A fresh checklist for the next service period is created. This one stays as it is.',
                confirmLabel: 'Start',
              );
              if (!ok || !context.mounted) return;
              final next = ref.read(checklistsProvider.notifier).startNextPeriod(checklist.id);
              if (next != null) {
                AppSnack.success(context, '${next.servicePeriod} checklist created');
                context.push(Routes.checklist(next.id));
              }
            },
          ),
        ],
        const SizedBox(height: 24),
        Text('Stage progress', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        StageStrip(stages: checklist.activeStages, currentId: checklist.currentStage?.id, onTap: _jumpTo),
        Text('Tap a segment to jump to that stage', style: AppText.caption),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: Text('Stages', style: AppText.sectionTitle)),
              if (checklist.currentStage != null)
                TextButton(onPressed: () => _jumpTo(checklist.currentStage!), child: const Text('Current stage')),
              TextButton(
                onPressed: () => setState(() {
                  if (allOpen) {
                    _expanded.clear();
                  } else {
                    _expanded.addAll(stages.map((s) => s.id));
                  }
                }),
                child: Text(allOpen ? 'Collapse all' : 'Expand all'),
              ),
            ],
          ),
        ),
        FilterChipRow<ItemFilter>(
          options: ItemFilter.values,
          allLabel: null,
          selected: _filter,
          labelOf: (f) => f.label,
          countOf: (f) => checklist.allItems.where((i) => f!.matches(i, me)).length,
          onSelected: (f) => setState(() => _filter = f ?? ItemFilter.all),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < stages.length; i++) _stageCard(checklist, stages[i], i, filtering),
      ],
    );
  }

  Widget _stageCard(ProjectChecklist checklist, ChecklistStage stage, int index, bool filtering) {
    final visible = stage.items.where((i) => _filter.matches(i, ref.read(currentMemberIdProvider))).toList();
    final hidden = filtering && visible.isEmpty;
    // While filtering, stages with matches open by themselves.
    final expanded = hidden ? false : (filtering || _expanded.contains(stage.id));

    return KeyedSubtree(
      key: _keyFor(stage.id),
      child: ChecklistStageCard(
        stage: stage,
        number: index + 1,
        expanded: expanded,
        hiddenByFilter: hidden,
        onToggle: () => setState(() => _expanded.contains(stage.id) ? _expanded.remove(stage.id) : _expanded.add(stage.id)),
        children: [
          for (final item in visible)
            ChecklistItemTile(
              key: ValueKey(item.id),
              item: item,
              onOpen: () => showItemDetail(context, checklist.id, item.id),
              onChangeStatus: () => changeItemStatus(context, ref, checklist.id, item),
            ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.checklist, required this.projectName, required this.clientName, required this.onOpenProject});
  final ProjectChecklist checklist;
  final String? projectName;
  final String? clientName;
  final VoidCallback? onOpenProject;

  @override
  Widget build(BuildContext context) {
    final status = checklist.status;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(onTap: onOpenProject, child: Text(projectName ?? 'Unknown project', style: AppText.sectionTitle)),
                    const SizedBox(height: 2),
                    Text(clientName ?? 'Unknown client', style: AppText.label),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              status.badge,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.percent(checklist.progress), style: AppText.display),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${checklist.requiredDone} of ${checklist.requiredTotal} required items', style: AppText.label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(value: checklist.progress, color: checklist.progressColor, height: 10),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _Fact(label: 'Service', value: [checklist.templateName, ?checklist.servicePeriod].join(' · ')),
          _Fact(label: 'Started', value: Fmt.date(checklist.createdAt)),
          if (checklist.currentStage != null)
            _Fact(label: 'Current stage', value: '${checklist.stages.indexOf(checklist.currentStage!) + 1}. ${checklist.currentStage!.name}')
          else
            const _Fact(label: 'Current stage', value: 'Finished'),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 104, child: Text(label, style: AppText.label)),
            Expanded(child: Text(value, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.checklist});
  final ProjectChecklist checklist;

  @override
  Widget build(BuildContext context) {
    final c = checklist;
    return MetricGrid(
      children: [
        MetricCard(label: 'Completed items', value: '${c.completedCount}', color: AppColors.success),
        MetricCard(label: 'Pending items', value: '${c.pendingCount}'),
        MetricCard(label: 'Required done', value: '${c.requiredDone}/${c.requiredTotal}', caption: 'Drives progress'),
        MetricCard(label: 'Waiting on client', value: '${c.waitingCount}', color: AppColors.warning, caption: c.waitingCount == 0 ? null : 'Needs a follow-up', captionColor: AppColors.warning),
        MetricCard(label: 'Blocked stages', value: '${c.blockedStageCount}', color: AppColors.danger),
        MetricCard(label: 'Overdue items', value: '${c.overdueCount}', color: AppColors.danger),
      ],
    );
  }
}

class _NextAction extends StatelessWidget {
  const _NextAction({required this.checklist, required this.onOpen});
  final ProjectChecklist checklist;
  final ValueChanged<ChecklistItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final item = checklist.nextAction;
    if (item == null) {
      return AppCard(
        shadow: false,
        color: AppColors.tint(AppColors.success, 0.08),
        child: Text('Every required item is complete. This delivery is ready to close.', style: AppText.bodyStrong.copyWith(color: AppColors.success)),
      );
    }
    final stage = checklist.stageOf(item.id)!;
    final waiting = item.status == ChecklistItemStatus.waitingClient;
    return AppCard(
      onTap: () => onOpen(item),
      shadow: false,
      color: AppColors.tint(waiting ? AppColors.warning : AppColors.primary, 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(waiting ? 'NEXT: FOLLOW UP WITH CLIENT' : 'NEXT ACTION', style: AppText.caption.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700, color: waiting ? AppColors.warning : AppColors.primary)),
          const SizedBox(height: 6),
          Text(item.title, style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text(
            [stage.name, if (item.dueDate != null) (item.isOverdue ? 'overdue since ${Fmt.dateShort(item.dueDate!)}' : 'due ${Fmt.dateShort(item.dueDate!)}')].join('  ·  '),
            style: AppText.caption.copyWith(color: item.isOverdue ? AppColors.danger : AppColors.muted),
          ),
        ],
      ),
    );
  }
}
