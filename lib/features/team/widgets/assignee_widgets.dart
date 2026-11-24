import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../team_providers.dart';
import '../team_workload.dart';

/// Small initials avatar for whoever something is assigned to. Shows nothing when unassigned.
class AssigneeAvatar extends ConsumerWidget {
  const AssigneeAvatar({super.key, required this.memberId, this.size = 24});
  final String? memberId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberProvider(memberId));
    if (member == null) return const SizedBox.shrink();
    return Tooltip(message: member.name, child: InitialsAvatar(name: member.name, size: size));
  }
}

/// Dropdown for forms. Includes "Unassigned" and keeps a deactivated member visible
/// if the record already belongs to them.
class AssigneeDropdown extends ConsumerWidget {
  const AssigneeDropdown({super.key, required this.value, required this.onChanged, this.label = 'Assigned to'});
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamProvider);
    final ids = [for (final m in members) if (m.active || m.id == value) m.id];
    return AppDropdown<String?>(
      label: label,
      hint: 'Unassigned',
      items: [null, ...ids],
      value: value,
      labelOf: (id) {
        if (id == null) return 'Unassigned';
        final m = members.firstWhere((m) => m.id == id);
        return '${m.name}  ·  ${m.role.label}${m.active ? '' : ' (inactive)'}';
      },
      onChanged: onChanged,
    );
  }
}

/// Bottom sheet to choose who gets something. Resolves to `(id: ...)`, where id is null for
/// "Unassigned", or to null if dismissed.
Future<({String? id})?> showAssigneePicker(BuildContext context, {String? currentId, String title = 'Assign to'}) {
  return showAppSheet<({String? id})>(
    context,
    title: title,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final members = ref.watch(activeMembersProvider);
        Widget row(String? id, String name, String subtitle) => InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(ctx, (id: id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    id == null
                        ? Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5)))
                        : InitialsAvatar(name: name, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(name, style: AppText.bodyStrong), Text(subtitle, style: AppText.caption)],
                      ),
                    ),
                    if (id == currentId) const Icon(Icons.check_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            );

        return Column(
          children: [
            row(null, 'Unassigned', 'Nobody owns this yet'),
            for (final m in members)
              row(m.id, m.name, '${m.role.label}  ·  ${ref.watch(workloadProvider(m.id)).total} open items'),
          ],
        );
      },
    ),
  );
}

/// A "label, avatar, name, Change" row for detail pages. Tapping opens the picker.
class AssigneeRow extends ConsumerWidget {
  const AssigneeRow({super.key, required this.label, required this.memberId, required this.onChanged});
  final String label;
  final String? memberId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(memberNameProvider(memberId));
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final pick = await showAssigneePicker(context, currentId: memberId, title: label);
        if (pick != null) onChanged(pick.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            memberId == null
                ? Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5)))
                : AssigneeAvatar(memberId: memberId, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label, style: AppText.caption), Text(name, style: AppText.bodyStrong)],
              ),
            ),
            Text('Change', style: AppText.labelStrong.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}