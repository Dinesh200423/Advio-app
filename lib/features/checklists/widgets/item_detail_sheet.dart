import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/checklist.dart';
import '../../../shared/widgets/notes_section.dart';
import '../../team/widgets/assignee_widgets.dart';
import '../checklist_providers.dart';
import 'checklist_style.dart';
import 'item_actions.dart';

/// Full details for one item, as a draggable bottom sheet.
Future<void> showItemDetail(BuildContext context, String checklistId, String itemId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, controller) => ItemDetailBody(checklistId: checklistId, itemId: itemId, controller: controller),
    ),
  );
}

class ItemDetailBody extends ConsumerWidget {
  const ItemDetailBody({super.key, required this.checklistId, required this.itemId, required this.controller});
  final String checklistId;
  final String itemId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklist = ref.watch(checklistProvider(checklistId));
    final item = checklist?.item(itemId);
    if (checklist == null || item == null) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('This item no longer exists.')));
    }
    final stage = checklist.stageOf(itemId)!;
    final notifier = ref.read(checklistsProvider.notifier);
    final waiting = item.status == ChecklistItemStatus.waitingClient;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            StatusBadge(label: item.isRequired ? 'Required' : 'Optional', color: item.isRequired ? AppColors.primary : AppColors.muted, dot: false),
            if (item.clientDependent) ...[const SizedBox(width: 8), const StatusBadge(label: 'Needs client', color: AppColors.secondary, dot: false)],
            const SizedBox(width: 10),
            Expanded(child: Text(stage.name, style: AppText.caption, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
        Text(item.title, style: AppText.sectionTitle.copyWith(fontSize: 20)),
        const SizedBox(height: 14),
        Row(
          children: [
            item.status.badge,
            const Spacer(),
            AppButton.secondary(label: 'Change status', compact: true, expand: false, onPressed: () => changeItemStatus(context, ref, checklistId, item)),
          ],
        ),
        if (waiting) ...[
          const SizedBox(height: 12),
          _Callout(color: AppColors.warning, text: 'Waiting on the client. This holds up the stage until they respond.'),
        ],
        if (item.status == ChecklistItemStatus.skipped) ...[
          const SizedBox(height: 12),
          _Callout(color: AppColors.secondary, text: 'Skipped: ${item.skipReason}'),
        ],
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(item.description, style: AppText.body),
        ],
        const SizedBox(height: 14),
        AssigneeRow(label: 'Assigned to', memberId: item.assigneeId, onChanged: (id) => notifier.setAssignee(checklistId, itemId, id)),
        const SizedBox(height: 14),
        InfoCard(children: [
          _DueRow(item: item, checklistId: checklistId),
          if (item.completedAt != null)
            InfoRow(label: item.status == ChecklistItemStatus.skipped ? 'Skipped on' : 'Completed on', value: Fmt.date(item.completedAt!)),
        ]),
        const SectionHeader(title: 'Evidence'),
        Text(
          item.evidenceType == EvidenceType.none ? 'No evidence is required for this item.' : 'Required: ${item.evidenceType.requirement(item.evidenceHint)}',
          style: AppText.label,
        ),
        const SizedBox(height: 12),
        for (final e in item.evidence)
          EvidenceCard(
            evidence: e,
            onRemove: () async {
              final ok = await confirmDialog(context, title: 'Remove evidence?', message: 'It will be removed from this item.', confirmLabel: 'Remove', destructive: true);
              if (ok) notifier.removeEvidence(checklistId, itemId, e.id);
            },
          ),
        if (item.evidenceType != EvidenceType.none)
          AppButton.secondary(
            label: item.evidence.isEmpty ? 'Add evidence' : 'Add more evidence',
            onPressed: () async {
              final ev = await showEvidenceSheet(context, item);
              if (ev != null) {
                notifier.addEvidence(checklistId, itemId, ev);
                if (context.mounted) AppSnack.success(context, 'Evidence added');
              }
            },
          ),
        const SectionHeader(title: 'Notes'),
        NotesSection(notes: item.notes, onAdd: (t) => notifier.addNote(checklistId, itemId, t), hint: 'Add a note about this item…'),
        const SectionHeader(title: 'Activity'),
        if (item.history.isEmpty)
          Text('Nothing has happened on this item yet.', style: AppText.label)
        else
          AppCard(
            child: Timeline(entries: [
              for (final h in item.history) TimelineEntry(title: h.title, subtitle: h.detail, time: Fmt.dateTime(h.at), color: AppColors.muted),
            ]),
          ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.tint(color, 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Text(text, style: AppText.body.copyWith(fontSize: 13.5)),
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({required this.item, required this.checklistId});
  final ChecklistItem item;
  final String checklistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(checklistsProvider.notifier);
    final due = item.dueDate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Due date', style: AppText.label),
                const SizedBox(height: 2),
                Text(
                  due == null ? 'Not set' : Fmt.date(due),
                  style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500, color: item.isOverdue ? AppColors.danger : (due == null ? AppColors.muted : AppColors.ink)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: due ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
              );
              if (picked != null) notifier.setDueDate(checklistId, item.id, picked);
            },
            child: Text(due == null ? 'Set date' : 'Change'),
          ),
          if (due != null)
            TextButton(
              onPressed: () => notifier.setDueDate(checklistId, item.id, null),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}
