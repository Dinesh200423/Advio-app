import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/task.dart';
import '../projects/project_providers.dart';
import '../team/team_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'task_providers.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.id, this.projectId});
  final String? id;
  final String? projectId;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late final Task? _existing = widget.id == null ? null : ref.read(tasksProvider.notifier).byId(widget.id);
  late final _title = TextEditingController(text: _existing?.title);
  late final _description = TextEditingController(text: _existing?.description);
  late String? _projectId = _existing?.projectId ?? widget.projectId;
  // New tasks start assigned to whoever is creating them.
  late String? _assigneeId = _existing == null ? ref.read(currentMemberIdProvider) : _existing.assigneeId;
  late Priority _priority = _existing?.priority ?? Priority.medium;
  late TaskStatus _status = _existing?.status ?? TaskStatus.todo;
  late DateTime? _due = _existing?.dueDate ?? DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Task', fallback: Routes.tasks);
    final editing = _existing != null;
    final projects = ref.watch(projectsProvider);

    return FormPage(
      title: editing ? 'Edit task' : 'Add task',
      submitLabel: editing ? 'Save changes' : 'Add task',
      successMessage: editing ? 'Task updated' : 'Task added',
      onSubmit: () {
        final notifier = ref.read(tasksProvider.notifier);
        if (editing) {
          notifier.upsert(_existing.copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            projectId: _projectId,
            priority: _priority,
            status: _status,
            dueDate: _due,
            assigneeId: _assigneeId,
          ));
        } else {
          notifier.create(Task(
            id: newId('task'),
            title: _title.text.trim(),
            description: _description.text.trim(),
            projectId: _projectId,
            priority: _priority,
            status: _status,
            dueDate: _due!,
            createdAt: DateTime.now(),
            assigneeId: _assigneeId,
          ));
        }
        return true;
      },
      children: [
        AppTextField(controller: _title, label: 'Task title', required: true, hint: 'What needs to be done?', textCapitalization: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Title')),
        const FormGap(),
        AppTextField(controller: _description, label: 'Description', hint: 'Add details…', maxLines: 3),
        const FormGap(),
        const FieldLabel('Priority'),
        FilterChipRow<Priority>(options: Priority.values, selected: _priority, allLabel: null, labelOf: (p) => p.label, onSelected: (p) => setState(() => _priority = p ?? _priority)),
        const FormGap(),
        AppDateField(label: 'Due date', value: _due, required: true, onChanged: (d) => setState(() => _due = d)),
        const FormGap(),
        AppDropdown<String?>(
          label: 'Project',
          hint: 'No project',
          items: [null, for (final p in projects) p.id],
          value: _projectId,
          labelOf: (id) => id == null ? 'No project' : projects.firstWhere((p) => p.id == id).name,
          onChanged: (v) => setState(() => _projectId = v),
        ),
        const FormGap(),
        AssigneeDropdown(value: _assigneeId, onChanged: (v) => setState(() => _assigneeId = v)),
        const FormGap(),
        AppDropdown<TaskStatus>(label: 'Status', items: TaskStatus.values, value: _status, labelOf: (s) => s.label, onChanged: (v) => setState(() => _status = v ?? _status)),
      ],
    );
  }
}
