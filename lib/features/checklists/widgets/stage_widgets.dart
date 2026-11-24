import 'package:flutter/material.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/checklist.dart';
import 'checklist_style.dart';

/// Accordion section for one stage: summary header, collapsible item list.
class ChecklistStageCard extends StatelessWidget {
  const ChecklistStageCard({
    super.key,
    required this.stage,
    required this.number,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.hiddenByFilter = false,
  });

  final ChecklistStage stage;
  final int number;
  final bool expanded;
  final VoidCallback onToggle;

  /// The item tiles to show when expanded.
  final List<Widget> children;

  /// A filter is on and nothing in this stage matches it.
  final bool hiddenByFilter;

  @override
  Widget build(BuildContext context) {
    final status = stage.status;
    final color = status.color;
    final applicable = stage.totalCount;

    return Opacity(
      opacity: hiddenByFilter ? 0.45 : 1,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: status == StageStatus.completed ? color : AppColors.tint(color, 0.12), shape: BoxShape.circle),
                          child: status == StageStatus.completed
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : Text('$number', style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(stage.name, style: AppText.cardTitle.copyWith(fontSize: 15))),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: AppProgressBar(value: stage.progress, color: color, height: 6)),
                        const SizedBox(width: 10),
                        Text(Fmt.percent(stage.progress), style: AppText.labelStrong),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            applicable == 0
                                ? 'Nothing applicable'
                                : '${stage.doneCount} of $applicable done  ·  ${stage.requiredDone}/${stage.requiredTotal} required',
                            style: AppText.caption,
                          ),
                        ),
                        status.badge,
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          if (stage.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                              child: Text(stage.description, style: AppText.caption.copyWith(fontSize: 12.5)),
                            ),
                          if (children.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: Text('No items match this filter', style: AppText.caption)),
                            )
                          else
                            ...children,
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// A slim bar of one segment per stage, coloured by stage status. Tap a segment to jump to it.
class StageStrip extends StatelessWidget {
  const StageStrip({super.key, required this.stages, required this.onTap, this.currentId});
  final List<ChecklistStage> stages;
  final ValueChanged<ChecklistStage> onTap;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Tooltip(
              message: '${stages[i].name} · ${stages[i].status.label}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(stages[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    height: stages[i].id == currentId ? 10 : 6,
                    decoration: BoxDecoration(
                      color: stages[i].status == StageStatus.notStarted
                          ? AppColors.border
                          : (stages[i].status == StageStatus.inProgress
                              ? AppColors.primary.withValues(alpha: 0.35 + 0.65 * stages[i].progress)
                              : stages[i].status.color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
