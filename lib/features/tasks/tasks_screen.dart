import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/task.dart';
import '../team/team_providers.dart';
import 'task_providers.dart';
import 'widgets/task_tile.dart';

enum TaskView {
  all('All'),
  mine('My Tasks'),
  today('Today'),
  upcoming('Upcoming'),
  overdue('Overdue');

  const TaskView(this.label);
  final String label;

  /// [me] is the id of whoever is using the app, for "My Tasks".
  bool matches(Task t, String me) => switch (this) {
        TaskView.all => true,
        TaskView.mine => t.assigneeId == me,
        TaskView.today => !t.isDone && daysUntil(t.dueDate) == 0,
        TaskView.upcoming => !t.isDone && daysUntil(t.dueDate) > 0,
        TaskView.overdue => !t.isDone && daysUntil(t.dueDate) < 0,
      };

  static TaskView fromName(String? n) => TaskView.values.firstWhere((v) => v.name == n, orElse: () => TaskView.all);
}

/// Stands in for "nobody" in the assignee filter, since null already means "any".
const _unassigned = '__unassigned';

class _TaskFilters {
  const _TaskFilters({this.status, this.priority, this.assignee});
  final TaskStatus? status;
  final Priority? priority;

  /// A member id, [_unassigned], or null for anyone.
  final String? assignee;

  int get count => [status, priority, assignee].where((f) => f != null).length;
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.initialView = TaskView.all, this.initialAssignee});
  final TaskView initialView;

  /// Start filtered to one member's tasks (an id), or "none" for unassigned.
  final String? initialAssignee;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  late TaskView _view = widget.initialView;
  late _TaskFilters _filters = _TaskFilters(assignee: widget.initialAssignee == 'none' ? _unassigned : widget.initialAssignee);
  String _query = '';

  Future<void> _openFilters() async {
    final result = await showAppSheet<_TaskFilters>(context, title: 'Filter tasks', builder: (_) => _FiltersForm(initial: _filters));
    if (result != null) setState(() => _filters = result);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tasksProvider);
    final me = ref.watch(currentMemberIdProvider);
    final q = _query.trim().toLowerCase();
    final f = _filters;

    final tasks = all.where((t) {
      if (!_view.matches(t, me)) return false;
      if (f.status != null && t.status != f.status) return false;
      if (f.priority != null && t.priority != f.priority) return false;
      if (f.assignee == _unassigned && t.assigneeId != null) return false;
      if (f.assignee != null && f.assignee != _unassigned && t.assigneeId != f.assignee) return false;
      return q.isEmpty || t.title.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });

    final filtering = q.isNotEmpty || f.count > 0;
    final emptyMessage = switch (_view) {
      TaskView.today => 'Nothing due today. Nice!',
      TaskView.overdue => 'No overdue tasks. You\'re on top of things.',
      TaskView.upcoming => 'No upcoming tasks scheduled.',
      TaskView.mine => 'No tasks assigned to you.',
      TaskView.all => 'Create your first task to get started.',
    };

    return PageScaffold(
      title: 'Tasks',
      onRefresh: () => pullToRefresh(context),
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.taskNew()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
      header: Column(
        children: [
          Row(
            children: [
              Expanded(child: AppSearchBar(hint: 'Search tasks', onChanged: (v) => setState(() => _query = v))),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: f.count > 0,
                label: Text('${f.count}'),
                backgroundColor: AppColors.ink,
                child: IconButton.outlined(
                  tooltip: 'Filters',
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: AppColors.surface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilterChipRow<TaskView>(
            options: TaskView.values,
            allLabel: null,
            selected: _view,
            labelOf: (v) => v.label,
            countOf: (v) => all.where((t) => v!.matches(t, me)).length,
            onSelected: (v) => setState(() => _view = v ?? _view),
          ),
        ],
      ),
      children: [
        if (tasks.isEmpty)
          EmptyState(
            icon: filtering ? Icons.search_off_rounded : Icons.task_alt_rounded,
            title: filtering ? 'No tasks match' : 'All clear',
            message: filtering ? 'Try changing your filters.' : emptyMessage,
            actionLabel: filtering ? 'Clear filters' : null,
            onAction: () => setState(() {
              _query = '';
              _filters = const _TaskFilters();
            }),
          )
        else
          for (final t in tasks) TaskTile(task: t),
      ],
    );
  }
}

class _FiltersForm extends ConsumerStatefulWidget {
  const _FiltersForm({required this.initial});
  final _TaskFilters initial;

  @override
  ConsumerState<_FiltersForm> createState() => _FiltersFormState();
}

class _FiltersFormState extends ConsumerState<_FiltersForm> {
  late TaskStatus? _status = widget.initial.status;
  late Priority? _priority = widget.initial.priority;
  late String? _assignee = widget.initial.assignee;

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDropdown<TaskStatus?>(label: 'Status', hint: 'Any status', items: [null, ...TaskStatus.values], value: _status, labelOf: (s) => s?.label ?? 'Any status', onChanged: (v) => setState(() => _status = v)),
        const SizedBox(height: 16),
        AppDropdown<Priority?>(label: 'Priority', hint: 'Any priority', items: [null, ...Priority.values], value: _priority, labelOf: (p) => p?.label ?? 'Any priority', onChanged: (v) => setState(() => _priority = v)),
        const SizedBox(height: 16),
        AppDropdown<String?>(
          label: 'Assigned to',
          hint: 'Anyone',
          items: [null, _unassigned, for (final m in members) m.id],
          value: _assignee,
          labelOf: (id) => id == null ? 'Anyone' : (id == _unassigned ? 'Unassigned' : members.firstWhere((m) => m.id == id).name),
          onChanged: (v) => setState(() => _assignee = v),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Apply filters', onPressed: () => Navigator.pop(context, _TaskFilters(status: _status, priority: _priority, assignee: _assignee))),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.pop(context, const _TaskFilters()), child: const Text('Clear all')),
      ],
    );
  }
}
