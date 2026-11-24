import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/lead.dart';
import '../../team/widgets/assignee_widgets.dart';

class LeadTile extends ConsumerWidget {
  const LeadTile({super.key, required this.lead, this.margin = const EdgeInsets.only(bottom: 12)});
  final Lead lead;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = lead.status.isOpen ? lead.nextFollowUp : null;
    final due = next != null && daysUntil(next.at) <= 0;

    return AppListTile(
      margin: margin,
      onTap: () => context.push(Routes.lead(lead.id)),
      leading: InitialsAvatar(name: lead.name),
      title: lead.name,
      subtitle: lead.company.isNotEmpty ? lead.company : lead.location,
      meta: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          lead.status.badge,
          AssigneeAvatar(memberId: lead.ownerId, size: 22),
          Text('${lead.service.shortLabel}  ·  ${lead.source.label}', style: AppText.caption),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ref.money(lead.estimatedValue, compact: true), style: AppText.bodyStrong),
          if (next != null) ...[
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_rounded, size: 12, color: due ? AppColors.warning : AppColors.muted),
              const SizedBox(width: 3),
              Text(
                Fmt.relativeDay(next.at),
                style: AppText.caption.copyWith(color: due ? AppColors.warning : AppColors.muted, fontWeight: due ? FontWeight.w600 : FontWeight.w400),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
