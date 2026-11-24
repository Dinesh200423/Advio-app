import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../projects/project_providers.dart';
import '../team/team_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'task_providers.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskProvider(id));
    if (task == null) return const MissingRecord(what: 'Task', fallback: Routes.tasks);
    final project = ref.watch(projectProvider(task.projectId ?? ''));
    final notifier = ref.read(tasksProvider.notifier);
    final overdue = isTaskOverdue(task);

    return PageScaffold(
      title: 'Task details',
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.taskEdit(id)),
          deleteTitle: 'Delete task?',
          deleteMessage: '"${task.title}" will be permanently removed.',
          onDelete: () {
            notifier.remove(id);
            context.popOr(Routes.tasks);
            AppSnack.success(context, 'Task deleted');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: AppText.sectionTitle.copyWith(decoration: task.isDone ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      final s = await pickOption<TaskStatus>(context, title: 'Task status', options: TaskStatus.values, labelOf: (s) => s.label, selected: task.status, colorOf: (s) => s.color);
                      if (s != null) notifier.setStatus(id, s);
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [task.status.badge, const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted)]),
                  ),
                  task.priority.badge,
                  if (overdue) const StatusBadge(label: 'Overdue', color: AppColors.danger, icon: Icons.warning_amber_rounded),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(task.description, style: AppText.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          children: [
            InfoRow(icon: Icons.event_rounded, label: 'Due date', value: '${Fmt.date(task.dueDate)} · ${Fmt.relativeDay(task.dueDate)}', valueColor: overdue ? AppColors.danger : null),
            InfoRow(icon: Icons.folder_outlined, label: 'Project', value: project?.name ?? '', onTap: project == null ? null : () => context.push(Routes.project(project.id))),
            InfoRow(
              label: 'Assigned to',
              value: ref.watch(memberNameProvider(task.assigneeId)),
              onTap: () async {
                final pick = await showAssigneePicker(context, currentId: task.assigneeId);
                if (pick != null) notifier.upsert(task.copyWith(assigneeId: pick.id));
              },
            ),
            InfoRow(icon: Icons.history_toggle_off_rounded, label: 'Created', value: Fmt.date(task.createdAt)),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(
          label: task.isDone ? 'Reopen task' : 'Mark as completed',
          icon: task.isDone ? Icons.undo_rounded : Icons.check_rounded,
          variant: task.isDone ? AppButtonVariant.secondary : AppButtonVariant.primary,
          onPressed: () {
            notifier.toggle(id);
            AppSnack.success(context, task.isDone ? 'Task reopened' : 'Task completed');
          },
        ),
      ],
    );
  }
}
