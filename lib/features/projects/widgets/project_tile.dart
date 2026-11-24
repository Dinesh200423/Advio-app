import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/project.dart';
import '../../clients/client_providers.dart';
import '../project_providers.dart';

class ProjectTile extends ConsumerWidget {
  const ProjectTile({super.key, required this.project, this.showClient = true, this.margin = const EdgeInsets.only(bottom: 12)});
  final Project project;
  final bool showClient;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(projectProgressProvider(project.id));
    final client = ref.watch(clientNameProvider(project.clientId));
    final late = project.status == ProjectStatus.active && daysUntil(project.endDate) < 0;

    return AppCard(
      margin: margin,
      onTap: () => context.push(Routes.project(project.id)),
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
                    Text(project.name, style: AppText.cardTitle.copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (showClient) Text(client, style: AppText.label),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              project.status.badge,
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(value: progress, showLabel: true, color: project.status.color),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(ref.money(project.budget, compact: true), style: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.body)),
              const Spacer(),
              Icon(Icons.flag_outlined, size: 14, color: late ? AppColors.danger : AppColors.muted),
              const SizedBox(width: 4),
              Text(
                late ? 'Overdue · ${Fmt.dateShort(project.endDate)}' : 'Ends ${Fmt.dateShort(project.endDate)}',
                style: AppText.caption.copyWith(color: late ? AppColors.danger : AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
