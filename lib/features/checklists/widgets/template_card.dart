import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/checklist.dart';
import '../checklist_providers.dart';

/// Library entry for one service template.
class TemplateCard extends ConsumerWidget {
  const TemplateCard({super.key, required this.template, required this.onEdit, required this.onDuplicate, required this.onDelete});
  final ChecklistTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = ref.watch(templateUsageProvider(template.id));
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(template.name, style: AppText.cardTitle.copyWith(fontSize: 15))),
                    const SizedBox(width: 8),
                    StatusBadge(label: template.category.label, color: template.isRecurring ? AppColors.secondary : AppColors.primary, dot: false),
                  ],
                ),
                if (template.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(template.description, style: AppText.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                Text('${template.stageCount} stages  ·  ${template.itemCount} items', style: AppText.labelStrong),
                const SizedBox(height: 2),
                Text(
                  'Updated ${Fmt.date(template.updatedAt)}${used == 0 ? '' : '  ·  used by $used project${used == 1 ? '' : 's'}'}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(onPressed: onEdit, child: const Text('Edit')),
              TextButton(onPressed: onDuplicate, child: const Text('Duplicate')),
              const Spacer(),
              TextButton(onPressed: onDelete, style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
