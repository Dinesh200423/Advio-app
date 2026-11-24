import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/checklist.dart';
import '../../clients/client_providers.dart';
import '../../projects/project_providers.dart';
import 'checklist_style.dart';

/// Compact progress card for a project checklist.
class ChecklistSummaryCard extends ConsumerWidget {
  const ChecklistSummaryCard({super.key, required this.checklist, this.showProject = true});
  final ProjectChecklist checklist;

  /// Lead with the project name (lists); otherwise lead with the template name (inside a project).
  final bool showProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(checklist.projectId));
    final client = project == null ? null : ref.watch(clientNameProvider(project.clientId));
    final stage = checklist.currentStage;
    final stageNumber = stage == null ? 0 : checklist.stages.indexOf(stage) + 1;
    final overdue = checklist.overdueCount;
    final waiting = checklist.waitingCount;
    final status = checklist.status;

    // Two short lines, so two checklists on one project (a build and its monthly care) are easy to tell apart.
    final line1 = showProject ? client : checklist.category.label;
    final line2 = [if (showProject) checklist.templateName, ?checklist.servicePeriod].join('  ·  ');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push(Routes.checklist(checklist.id)),
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
                    Text(showProject ? (project?.name ?? 'Unknown project') : checklist.templateName, style: AppText.cardTitle.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    if (line1 != null) Text(line1, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (line2.isNotEmpty) Text(line2, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              status.badge,
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: AppProgressBar(value: checklist.progress, color: checklist.progressColor)),
              const SizedBox(width: 10),
              Text(Fmt.percent(checklist.progress), style: AppText.labelStrong),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stage == null ? 'All required items are complete' : 'Stage $stageNumber of ${checklist.stages.length}: ${stage.name}',
            style: AppText.caption,
          ),
          if (waiting > 0 || overdue > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (waiting > 0) StatusBadge(label: '$waiting waiting on client', color: AppColors.warning),
                if (overdue > 0) StatusBadge(label: '$overdue overdue', color: AppColors.danger),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
