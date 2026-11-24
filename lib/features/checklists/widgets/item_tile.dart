import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/checklist.dart';
import '../../team/team_providers.dart';
import 'checklist_style.dart';

/// Round status indicator. Tapping it is the fast way to change an item's status.
class StatusControl extends StatelessWidget {
  const StatusControl({super.key, required this.status, required this.onTap});
  final ChecklistItemStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    final Widget mark = switch (status) {
      ChecklistItemStatus.done => const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ChecklistItemStatus.skipped => Icon(Icons.remove_rounded, size: 16, color: c),
      ChecklistItemStatus.notApplicable => Icon(Icons.remove_rounded, size: 16, color: c),
      ChecklistItemStatus.doing || ChecklistItemStatus.waitingClient => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      ChecklistItemStatus.todo => const SizedBox.shrink(),
    };
    return Tooltip(
      message: 'Status: ${status.label}. Tap to change',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: status == ChecklistItemStatus.done ? c : (status == ChecklistItemStatus.notApplicable ? AppColors.border : Colors.transparent),
                shape: BoxShape.circle,
                border: Border.all(color: status == ChecklistItemStatus.done ? c : c.withValues(alpha: 0.7), width: 2),
              ),
              child: mark,
            ),
          ),
        ),
      ),
    );
  }
}

/// One checklist item inside a stage. Waiting-on-client items are tinted so they stand out.
class ChecklistItemTile extends StatelessWidget {
  const ChecklistItemTile({super.key, required this.item, required this.onOpen, required this.onChangeStatus});
  final ChecklistItem item;
  final VoidCallback onOpen;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final waiting = item.status == ChecklistItemStatus.waitingClient;
    final muted = item.status == ChecklistItemStatus.notApplicable;
    final doneish = item.isResolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: waiting ? AppColors.tint(AppColors.warning, 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: waiting ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusControl(status: item.status, onTap: onChangeStatus),
              const SizedBox(width: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w500,
                          color: muted || doneish ? AppColors.muted : AppColors.ink,
                          decoration: muted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _Meta(item: item),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends ConsumerWidget {
  const _Meta({required this.item});
  final ChecklistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignee = ref.watch(memberProvider(item.assigneeId));
    final small = AppText.caption.copyWith(fontSize: 11.5);
    final chips = <Widget>[
      StatusBadge(label: item.isRequired ? 'Required' : 'Optional', color: item.isRequired ? AppColors.primary : AppColors.muted, dot: false),
      if (item.status == ChecklistItemStatus.waitingClient)
        const StatusBadge(label: 'Waiting on client', color: AppColors.warning)
      else if (item.clientDependent && !item.isResolved)
        const StatusBadge(label: 'Needs client', color: AppColors.secondary, dot: false),
      if (item.evidenceType != EvidenceType.none)
        StatusBadge(
          label: item.evidence.isNotEmpty ? '${item.evidenceType.label} added' : 'Needs ${item.evidenceType.label.toLowerCase()}',
          color: item.evidence.isNotEmpty ? AppColors.success : (item.isResolved ? AppColors.muted : AppColors.warning),
          dot: false,
        ),
    ];

    final line = <Widget>[];
    if (item.status == ChecklistItemStatus.done && item.completedAt != null) {
      line.add(Text('Done ${Fmt.dateShort(item.completedAt!)}', style: small.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)));
    } else if (item.status == ChecklistItemStatus.skipped) {
      line.add(Text('Skipped: ${item.skipReason ?? ''}', style: small.copyWith(color: AppColors.secondary), maxLines: 1, overflow: TextOverflow.ellipsis));
    } else if (item.dueDate != null && item.isApplicable) {
      line.add(Text(
        item.isOverdue ? 'Overdue · due ${Fmt.dateShort(item.dueDate!)}' : 'Due ${Fmt.dateShort(item.dueDate!)}',
        style: small.copyWith(color: item.isOverdue ? AppColors.danger : AppColors.muted, fontWeight: item.isOverdue ? FontWeight.w600 : FontWeight.w400),
      ));
    }
    if (assignee != null) line.add(Text(assignee.firstName, style: small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)));
    if (item.notes.isNotEmpty) {
      line.add(Text('${item.notes.length} note${item.notes.length == 1 ? '' : 's'}', style: small));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 6, runSpacing: 6, children: chips),
        if (line.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 2, children: line),
        ],
      ],
    );
  }
}
