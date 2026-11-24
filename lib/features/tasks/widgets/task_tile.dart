import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/task.dart';
import '../../projects/project_providers.dart';
import '../../team/widgets/assignee_widgets.dart';
import '../task_providers.dart';

/// Round, animated completion checkbox.
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: done ? 'Mark as not done' : 'Mark as done',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? AppColors.success : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: done ? AppColors.success : AppColors.muted.withValues(alpha: 0.5), width: 2),
              ),
              child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// List row for a task: checkbox, title, context line and priority.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.showProject = true, this.margin = const EdgeInsets.only(bottom: 12)});
  final Task task;
  final bool showProject;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = isTaskOverdue(task);
    final project = showProject ? ref.watch(projectNameProvider(task.projectId)) : null;
    final due = Fmt.relativeDay(task.dueDate);

    return AppCard(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
      onTap: () => context.push(Routes.task(task.id)),
      child: Row(
        children: [
          TaskCheck(done: task.isDone, onTap: () => ref.read(tasksProvider.notifier).toggle(task.id)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone ? AppColors.muted : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                // Wraps rather than truncating, so it still fits when the row is narrow.
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: overdue ? AppColors.danger : AppColors.muted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            task.isDone ? 'Done' : due,
                            style: AppText.caption.copyWith(
                              color: overdue ? AppColors.danger : AppColors.muted,
                              fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (project != null) Text(project, style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (task.assigneeId != null) ...[AssigneeAvatar(memberId: task.assigneeId), const SizedBox(width: 8)],
          if (!task.isDone) task.priority.badge else task.status.badge,
        ],
      ),
    );
  }
}
